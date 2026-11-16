import 'dart:math';

import '../models/boss_model.dart';
import '../models/card_model.dart';

/// 전투 결과 상태
enum CombatStatus {
  inProgress('전투 진행 중'),
  victory('전투 승리 (보스 토벌)'),
  defeat('전투 패배 (파티 전멸)');

  final String label;
  const CombatStatus(this.label);
}

/// 턴 중 파티원이 선택한 카드 및 타겟 부위 액션
class SelectedCardAction {
  final JobClass job;
  final CardModel card;
  final BossPartType targetPart;

  SelectedCardAction({
    required this.job,
    required this.card,
    this.targetPart = BossPartType.body,
  });

  @override
  String toString() => '${job.label}: ${card.name} -> ${targetPart.label}';
}

/// 개별 카드 실행 정산 결과
class CardActionResult {
  final JobClass job;
  final CardModel card;
  final BossPartType targetPart;
  final int chainCount;
  final double chainMultiplier;
  final double attrMultiplier;
  final int rawValue;
  final int effectiveValue;
  final String description;

  CardActionResult({
    required this.job,
    required this.card,
    required this.targetPart,
    required this.chainCount,
    required this.chainMultiplier,
    required this.attrMultiplier,
    required this.rawValue,
    required this.effectiveValue,
    required this.description,
  });
}

/// 턴 정산 종합 보고서
class CombatTurnReport {
  final int turnNumber;
  final CombatStatus status;
  final Map<CardAttribute, int> chainCounts;
  final List<CardActionResult> actions;
  final List<String> partDestroyedEvents;
  final int totalDamageDealt;
  final int totalHealingDone;
  final int partyDefenseBuff;
  final int bossRawAttack;
  final int bossActualDamage;
  final int previousEnrageStack;
  final int newEnrageStack;
  final int turnDrawBonus;
  final List<String> logs;

  CombatTurnReport({
    required this.turnNumber,
    required this.status,
    required this.chainCounts,
    required this.actions,
    required this.partDestroyedEvents,
    required this.totalDamageDealt,
    required this.totalHealingDone,
    required this.partyDefenseBuff,
    required this.bossRawAttack,
    required this.bossActualDamage,
    required this.previousEnrageStack,
    required this.newEnrageStack,
    required this.turnDrawBonus,
    required this.logs,
  });
}

/// 파티원의 전투 상태 모델
class PartyMemberState {
  final JobClass job;
  final int maxHp;
  int currentHp;
  int currentAp;
  int maxAp;

  final List<CardModel> drawPile;
  final List<CardModel> hand;
  final List<CardModel> discardPile;
  final List<SelectedCardAction> selectedActions;

  PartyMemberState({
    required this.job,
    required this.maxHp,
    required List<CardModel> initialDeck,
  })  : currentHp = maxHp,
        currentAp = 3,
        maxAp = 3,
        drawPile = List.from(initialDeck),
        hand = [],
        discardPile = [],
        selectedActions = [];

  bool get isDead => currentHp <= 0;
  bool get isAlive => currentHp > 0;
  double get hpRatio => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  /// 피해 적용 (0 이하 시 사망 처리)
  int takeDamage(int damage) {
    if (isDead || damage <= 0) return 0;
    final actual = damage.clamp(0, currentHp);
    currentHp -= damage;
    if (currentHp < 0) currentHp = 0;
    return actual;
  }

  /// 회복 적용 (최대 HP 한도)
  int heal(int amount) {
    if (isDead || amount <= 0) return 0;
    final missingHp = maxHp - currentHp;
    final actual = amount.clamp(0, missingHp);
    currentHp += actual;
    return actual;
  }
}

/// 순수 Dart로 구현된 4인 파티 보스 레이드 전투 엔진
class CombatEngine {
  static const int maxHandSize = 5;
  static const int maxApLimit = 10;

  final Random _random;
  final BossModel boss;
  final Map<JobClass, PartyMemberState> party = {};

  int turnNumber = 1;
  CombatStatus combatStatus = CombatStatus.inProgress;

  CombatEngine({
    required Map<JobClass, List<CardModel>> decks,
    BossModel? boss,
    Random? random,
  })  : boss = boss ?? BossModel.createDefaultDragon(),
        _random = random ?? Random() {
    _initializeParty(decks);
    _startFirstTurn();
  }

  /// 4인 파티 상태 초기화 (Leader 카드 1.5배 보너스 반영 및 HP 산출)
  void _initializeParty(Map<JobClass, List<CardModel>> decks) {
    for (final job in JobClass.values) {
      final deck = decks[job];
      if (deck == null || deck.length != 10) {
        throw ArgumentError('${job.label}의 덱은 정확히 10장이어야 합니다.');
      }

      // 0번 인덱스 리더 카드는 1.5배 보너스 적용
      final processedDeck = <CardModel>[];
      for (int i = 0; i < deck.length; i++) {
        if (i == 0) {
          processedDeck.add(deck[i].applyLeaderBonus());
        } else {
          processedDeck.add(deck[i]);
        }
      }

      // 파티원 최대 HP = 덱 전체 카드의 (value * 5) 합산 (기존 MainDeckScreen 스탯 공식 고증)
      final calculatedHp = processedDeck.fold<int>(
        0,
        (sum, card) => sum + (card.value * 5),
      );

      party[job] = PartyMemberState(
        job: job,
        maxHp: calculatedHp,
        initialDeck: processedDeck,
      );
    }
  }

  /// 1턴 시작: 셔플 및 5장 드로우, 초기 AP 3 세팅
  void _startFirstTurn() {
    turnNumber = 1;
    combatStatus = CombatStatus.inProgress;

    for (final member in party.values) {
      member.drawPile.shuffle(_random);
      _drawCardsForMember(member, maxHandSize);
      member.maxAp = _calculateApForTurn(turnNumber);
      member.currentAp = member.maxAp;
      member.selectedActions.clear();
    }
  }

  /// 턴에 따른 AP 계산 (기본 3, 매 턴 +1, 최대 10)
  int _calculateApForTurn(int turn) {
    return (3 + (turn - 1)).clamp(3, maxApLimit);
  }

  /// 특정 파티원 카드 드로우 (손패 상한 5장 엄수, 덱 소진 시 버린 카드 셔플 재활용)
  void _drawCardsForMember(PartyMemberState member, int count) {
    int drawn = 0;
    while (drawn < count && member.hand.length < maxHandSize) {
      if (member.drawPile.isEmpty) {
        if (member.discardPile.isEmpty) {
          // 뽑을 카드가 완전히 없음
          break;
        }
        member.drawPile.addAll(member.discardPile);
        member.drawPile.shuffle(_random);
        member.discardPile.clear();
      }

      final card = member.drawPile.removeAt(0);
      member.hand.add(card);
      drawn++;
    }
  }

  // ==========================================
  // 속성 상성 및 체인 규칙
  // ==========================================

  /// 속성 상성 배율: 불 > 바람 > 물 > 불 (상극 2.0배, 역상성 0.5배, 동일/기타 1.0배)
  static double getAttributeMultiplier(
    CardAttribute attacker,
    CardAttribute defender,
  ) {
    if (attacker == CardAttribute.fire && defender == CardAttribute.wind) {
      return 2.0;
    }
    if (attacker == CardAttribute.wind && defender == CardAttribute.water) {
      return 2.0;
    }
    if (attacker == CardAttribute.water && defender == CardAttribute.fire) {
      return 2.0;
    }
    if (attacker == CardAttribute.wind && defender == CardAttribute.fire) {
      return 0.5;
    }
    if (attacker == CardAttribute.water && defender == CardAttribute.wind) {
      return 0.5;
    }
    if (attacker == CardAttribute.fire && defender == CardAttribute.water) {
      return 0.5;
    }
    return 1.0;
  }

  /// 4명 파티원의 동일 속성 카드 수에 따른 체인 배율 (2체인 1.2배, 3체인 1.5배, 4체인 2.0배)
  static double getChainMultiplier(int chainCount) {
    if (chainCount >= 4) return 2.0;
    if (chainCount == 3) return 1.5;
    if (chainCount == 2) return 1.2;
    return 1.0;
  }

  /// 현재 파티원들이 선택한 카드들의 속성별 체인 개수 (실시간 집계)
  Map<CardAttribute, int> get currentChainCounts {
    final counts = {
      CardAttribute.fire: 0,
      CardAttribute.wind: 0,
      CardAttribute.water: 0,
    };
    for (final member in party.values) {
      for (final action in member.selectedActions) {
        counts[action.card.attribute] =
            (counts[action.card.attribute] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// 현재 선택된 카드 중 파티 전체의 누적 drawBonus 합산
  int get currentPendingDrawBonus {
    int total = 0;
    for (final member in party.values) {
      for (final action in member.selectedActions) {
        total += action.card.drawBonus;
      }
    }
    return total;
  }

  // ==========================================
  // 카드 선택 및 AP 관리
  // ==========================================

  /// 카드를 선택 가능한지 검증
  bool canSelectCard(JobClass job, CardModel card) {
    final member = party[job];
    if (member == null || member.isDead) return false;
    if (!member.hand.contains(card)) return false;
    if (member.selectedActions.any((a) => a.card.id == card.id)) return false;
    return member.currentAp >= card.cost;
  }

  /// 카드 선택 (AP 차감 및 선택 목록 추가)
  bool selectCard(
    JobClass job,
    CardModel card, {
    BossPartType targetPart = BossPartType.body,
  }) {
    if (!canSelectCard(job, card)) return false;

    final member = party[job]!;
    member.currentAp -= card.cost;
    member.selectedActions.add(
      SelectedCardAction(job: job, card: card, targetPart: targetPart),
    );
    return true;
  }

  /// 카드 선택 취소 (AP 반환 및 선택 목록에서 제거)
  bool deselectCard(JobClass job, CardModel card) {
    final member = party[job];
    if (member == null) return false;

    final index = member.selectedActions.indexWhere(
      (a) => a.card.id == card.id,
    );
    if (index == -1) return false;

    member.selectedActions.removeAt(index);
    member.currentAp += card.cost;
    return true;
  }

  /// 특정 직업의 모든 선택 취소
  void clearSelection(JobClass job) {
    final member = party[job];
    if (member == null) return;
    for (final action in member.selectedActions) {
      member.currentAp += action.card.cost;
    }
    member.selectedActions.clear();
  }

  // ==========================================
  // AI 동료 자동 선택 로직
  // ==========================================

  /// 직업별 AI 규칙에 따른 자동 카드 선택
  void autoSelectForJob(JobClass job) {
    final member = party[job];
    if (member == null || member.isDead) return;

    clearSelection(job);

    switch (job) {
      case JobClass.bard:
        _autoSelectBard(member);
        break;
      case JobClass.wealthy:
        _autoSelectWealthy(member);
        break;
      case JobClass.thief:
        _autoSelectThief(member);
        break;
      case JobClass.mercenary:
        _autoSelectMercenary(member);
        break;
    }
  }

  /// 플레이어를 제외한 모든 AI 동료 자동 선택 (playerJob이 null이면 4명 전원 AI)
  void autoSelectAllAI({JobClass? playerJob}) {
    for (final job in JobClass.values) {
      if (job != playerJob) {
        autoSelectForJob(job);
      }
    }
  }

  /// 가희 AI: 아군 중 HP 70% 이하 존재 시 힐 카드 최우선 선택
  void _autoSelectBard(PartyMemberState member) {
    final hasLowHpAlly = party.values.any((m) => m.isAlive && m.hpRatio <= 0.70);

    final availableCards = List<CardModel>.from(member.hand);

    if (hasLowHpAlly) {
      // 힐 카드를 수치 높은 순으로 우선 정렬
      availableCards.sort((a, b) {
        if (a.isHealCard && !b.isHealCard) return -1;
        if (!a.isHealCard && b.isHealCard) return 1;
        return b.value.compareTo(a.value);
      });
    } else {
      // 힐이 급하지 않으면 수치 높은 순
      availableCards.sort((a, b) => b.value.compareTo(a.value));
    }

    _pickCardsWithinAp(member, availableCards, _pickBestTarget(CardAttribute.wind));
  }

  /// 부호 AI: 아군 손패가 3장 이하일 때 drawBonus 카드 또는 방어 카드 우선
  void _autoSelectWealthy(PartyMemberState member) {
    final hasLowHandAlly = party.values.any(
      (m) => m.isAlive && m.hand.length <= 3,
    );

    final availableCards = List<CardModel>.from(member.hand);

    if (hasLowHandAlly) {
      // drawBonus 카드 최우선 -> 방어 카드 우선 -> 수치 높은 순
      availableCards.sort((a, b) {
        if (a.drawBonus > 0 && b.drawBonus == 0) return -1;
        if (a.drawBonus == 0 && b.drawBonus > 0) return 1;
        if (a.drawBonus != b.drawBonus) return b.drawBonus.compareTo(a.drawBonus);
        if (a.isDefenseCard && !b.isDefenseCard) return -1;
        if (!a.isDefenseCard && b.isDefenseCard) return 1;
        return b.value.compareTo(a.value);
      });
    } else {
      // 방어 카드 우선 -> 수치 높은 순
      availableCards.sort((a, b) {
        if (a.isDefenseCard && !b.isDefenseCard) return -1;
        if (!a.isDefenseCard && b.isDefenseCard) return 1;
        return b.value.compareTo(a.value);
      });
    }

    _pickCardsWithinAp(member, availableCards, _pickBestTarget(CardAttribute.fire));
  }

  /// 도적 AI: 보유 AP 내 고코스트 / 고수치 카드 우선 (마법 공격/디버프 극대화)
  void _autoSelectThief(PartyMemberState member) {
    final availableCards = List<CardModel>.from(member.hand)
      ..sort((a, b) {
        // 코스트와 수치 종합 우선도
        final scoreA = (a.cost * 10000) + a.value;
        final scoreB = (b.cost * 10000) + b.value;
        return scoreB.compareTo(scoreA);
      });

    // 도적은 무기 공격력 디버프 및 파괴를 위해 무기 우선 타겟팅
    final target = !boss.isWeaponDestroyed ? BossPartType.weapon : BossPartType.body;
    _pickCardsWithinAp(member, availableCards, target);
  }

  /// 용병 AI: 약점 속성 및 고데미지 물리 공격 카드 우선
  void _autoSelectMercenary(PartyMemberState member) {
    final target = _pickBestTarget(CardAttribute.fire);
    final targetAttr = boss.getPart(target).attribute;

    final availableCards = List<CardModel>.from(member.hand)
      ..sort((a, b) {
        final multA = getAttributeMultiplier(a.attribute, targetAttr);
        final multB = getAttributeMultiplier(b.attribute, targetAttr);
        final scoreA = (a.value * multA).round();
        final scoreB = (b.value * multB).round();
        return scoreB.compareTo(scoreA);
      });

    _pickCardsWithinAp(member, availableCards, target);
  }

  /// 최선의 보스 타겟 부위 결정 (무기 파괴 전이면 무기 > 방패 > 본체 순)
  BossPartType _pickBestTarget(CardAttribute attackerAttr) {
    if (!boss.isWeaponDestroyed) return BossPartType.weapon;
    if (!boss.isShieldDestroyed) return BossPartType.shield;
    return BossPartType.body;
  }

  /// AP 한도 내에서 카드를 순차적으로 선택
  void _pickCardsWithinAp(
    PartyMemberState member,
    List<CardModel> sortedCards,
    BossPartType target,
  ) {
    for (final card in sortedCards) {
      if (canSelectCard(member.job, card)) {
        selectCard(member.job, card, targetPart: target);
      }
    }
  }

  // ==========================================
  // 턴 종료 정산 (resolveTurn)
  // ==========================================

  /// 한 턴의 액션을 일괄 정산하고 다음 턴을 준비합니다.
  CombatTurnReport resolveTurn() {
    if (combatStatus != CombatStatus.inProgress) {
      throw StateError('전투가 이미 종료된 상태입니다 ($combatStatus).');
    }

    final logs = <String>[];
    final partDestroyedEvents = <String>[];
    final actionResults = <CardActionResult>[];

    logs.add('=== 제 $turnNumber 턴 전투 정산 시작 ===');

    // 1. 체인 수 집계 (4명이 낸 동일 속성 카드 수)
    final chainCounts = {
      CardAttribute.fire: 0,
      CardAttribute.wind: 0,
      CardAttribute.water: 0,
    };

    int turnDrawBonusTotal = 0;

    for (final member in party.values) {
      for (final action in member.selectedActions) {
        chainCounts[action.card.attribute] =
            (chainCounts[action.card.attribute] ?? 0) + 1;
        turnDrawBonusTotal += action.card.drawBonus;
      }
    }

    logs.add(
      '체인 현황: 불(${chainCounts[CardAttribute.fire]}), '
      '바람(${chainCounts[CardAttribute.wind]}), '
      '물(${chainCounts[CardAttribute.water]})',
    );

    int totalPartyDefense = 0;
    int totalDamageDealt = 0;
    int totalHealingDone = 0;
    int thiefDebuffReduction = 0;

    // 2. 파티원 액션 실행 (순서: 부호 방어 -> 가희 회복 -> 도적 디버프/마공 -> 용병 물공)
    final executionOrder = [
      JobClass.wealthy,
      JobClass.bard,
      JobClass.thief,
      JobClass.mercenary,
    ];

    for (final job in executionOrder) {
      final member = party[job]!;
      if (member.isDead) continue;

      for (final action in member.selectedActions) {
        final card = action.card;
        final chain = chainCounts[card.attribute] ?? 1;
        final chainMult = getChainMultiplier(chain);

        // 타겟 부위 확인 (이미 파괴된 부위라면 본체로 자동 리디렉션)
        var targetType = action.targetPart;
        if (boss.getPart(targetType).isDestroyed && !boss.isDefeated) {
          targetType = BossPartType.body;
        }
        final targetPart = boss.getPart(targetType);

        if (card.isDefenseCard) {
          // 부호: 방어 버프 (체인 배율 반영)
          final defValue = (card.value * chainMult).round();
          totalPartyDefense += defValue;

          final result = CardActionResult(
            job: job,
            card: card,
            targetPart: targetType,
            chainCount: chain,
            chainMultiplier: chainMult,
            attrMultiplier: 1.0,
            rawValue: card.value,
            effectiveValue: defValue,
            description: '${job.label}의 방어막 전개: +$defValue 방어력 획득 ($chain체인)',
          );
          actionResults.add(result);
          logs.add(result.description);
        } else if (card.isHealCard) {
          // 가희: 아군 전체 회복 (체인 배율 반영)
          final healValue = (card.value * chainMult).round();
          int healedInThisCard = 0;
          for (final ally in party.values) {
            if (ally.isAlive) {
              healedInThisCard += ally.heal(healValue);
            }
          }
          totalHealingDone += healedInThisCard;

          final result = CardActionResult(
            job: job,
            card: card,
            targetPart: targetType,
            chainCount: chain,
            chainMultiplier: chainMult,
            attrMultiplier: 1.0,
            rawValue: card.value,
            effectiveValue: healValue,
            description: '${job.label}의 전체 치유: 아군 전원 $healValue 회복 ($chain체인)',
          );
          actionResults.add(result);
          logs.add(result.description);
        } else if (card.isDebuffCard) {
          // 도적: 마법 공격 및 보스 공격력 디버프
          final attrMult = getAttributeMultiplier(card.attribute, targetPart.attribute);
          double dmg = card.value * chainMult * attrMult;

          // 보스 방패 유지 시 피해 경감 적용
          if (!boss.isShieldDestroyed) {
            dmg *= (1.0 - boss.defenseReduction);
          }
          final finalDmg = dmg.round();
          final actualDmg = targetPart.takeDamage(finalDmg);
          totalDamageDealt += actualDmg;

          // 공격력 디버프 효과 (수치의 20%를 보스 공격력에서 차감)
          final debuffAmt = (card.value * 0.20 * chainMult).round();
          thiefDebuffReduction += debuffAmt;

          final result = CardActionResult(
            job: job,
            card: card,
            targetPart: targetType,
            chainCount: chain,
            chainMultiplier: chainMult,
            attrMultiplier: attrMult,
            rawValue: card.value,
            effectiveValue: actualDmg,
            description: '${job.label}의 마법공격 및 약화: ${targetPart.name}에 $actualDmg 데미지, 공격력 -$debuffAmt 약화 ($chain체인, 상성 ${attrMult}x)',
          );
          actionResults.add(result);
          logs.add(result.description);
        } else {
          // 용병: 강력한 물리 공격
          final attrMult = getAttributeMultiplier(card.attribute, targetPart.attribute);
          double dmg = card.value * chainMult * attrMult;

          // 보스 방패 유지 시 피해 경감 적용
          if (!boss.isShieldDestroyed) {
            dmg *= (1.0 - boss.defenseReduction);
          }
          final finalDmg = dmg.round();
          final actualDmg = targetPart.takeDamage(finalDmg);
          totalDamageDealt += actualDmg;

          final result = CardActionResult(
            job: job,
            card: card,
            targetPart: targetType,
            chainCount: chain,
            chainMultiplier: chainMult,
            attrMultiplier: attrMult,
            rawValue: card.value,
            effectiveValue: actualDmg,
            description: '${job.label}의 물리타격: ${targetPart.name}에 $actualDmg 데미지! ($chain체인, 상성 ${attrMult}x)',
          );
          actionResults.add(result);
          logs.add(result.description);
        }

        // 보스 부위 신규 파괴 체크
        _checkPartDestruction(logs, partDestroyedEvents);

        // 보스 본체 파괴 시 즉시 승리
        if (boss.isDefeated) {
          combatStatus = CombatStatus.victory;
          logs.add('★ 보스의 본체가 파괴되었습니다! 아군 파티의 승리! ★');
          break;
        }
      }

      if (boss.isDefeated) break;
    }

    int bossRawAttack = 0;
    int actualBossDamage = 0;

    // 3. 보스 반격 (본체가 살아남은 경우에만 실행)
    if (!boss.isDefeated) {
      bossRawAttack = boss.calculateTurnAttack();

      // 도적 디버프 적용
      int effectiveBossAttack = max(0, bossRawAttack - thiefDebuffReduction);

      // 부호 방어막 적용 후 최종 파티 피해 산출
      actualBossDamage = max(0, effectiveBossAttack - totalPartyDefense);

      logs.add(
        '보스 반격: 기본 공격력 $bossRawAttack (광폭화 배율 ${boss.attackMultiplier.toStringAsFixed(2)}x) '
        '-> 도적 디버프(-$thiefDebuffReduction) -> 부호 방어막(-$totalPartyDefense) = 파티원당 $actualBossDamage 피해',
      );

      // 살아있는 파티원 전원에게 피해 적용
      for (final member in party.values) {
        if (member.isAlive) {
          member.takeDamage(actualBossDamage);
          if (member.isDead) {
            logs.add('☠ ${member.job.label}이(가) 보스의 공격에 쓰러졌습니다!');
          }
        }
      }

      // 파티 전멸 체크
      if (party.values.every((m) => m.isDead)) {
        combatStatus = CombatStatus.defeat;
        logs.add('파티 전원이 쓰러졌습니다... 패배!');
      }
    }

    final currentTurn = turnNumber;
    final prevEnrage = boss.enrageStack;

    // 4. 광폭화 스택 중첩 증가
    if (combatStatus == CombatStatus.inProgress) {
      boss.increaseEnrageStack();
      logs.add('보스 광폭화 스택 증가: ${boss.enrageStack}단계 (공격력 +20% 중첩)');
    }

    // 5. 다음 턴 준비 (카드 버리기, AP 충전, 드로우)
    _prepareNextTurn(turnDrawBonusTotal);

    return CombatTurnReport(
      turnNumber: currentTurn,
      status: combatStatus,
      chainCounts: chainCounts,
      actions: actionResults,
      partDestroyedEvents: partDestroyedEvents,
      totalDamageDealt: totalDamageDealt,
      totalHealingDone: totalHealingDone,
      partyDefenseBuff: totalPartyDefense,
      bossRawAttack: bossRawAttack,
      bossActualDamage: actualBossDamage,
      previousEnrageStack: prevEnrage,
      newEnrageStack: boss.enrageStack,
      turnDrawBonus: turnDrawBonusTotal,
      logs: logs,
    );
  }

  /// 보스 부위 파괴 여부 검사 및 안내 메시지 생성
  void _checkPartDestruction(List<String> logs, List<String> events) {
    if (boss.weapon.isDestroyed && !events.contains('weapon')) {
      events.add('weapon');
      final msg = '⚔ [무기 파괴!] 보스의 공격 패턴이 봉인되고 공격력이 50% 대폭 감소합니다!';
      logs.add(msg);
    }
    if (boss.shield.isDestroyed && !events.contains('shield')) {
      events.add('shield');
      final msg = '🛡 [방패 파괴!] 보스의 방어막이 파괴되어 피해 경감 효과가 사라집니다!';
      logs.add(msg);
    }
  }

  /// 다음 턴 준비: 손패 및 사용 카드 정리, AP 회복, 드로우 진행
  void _prepareNextTurn(int previousTurnDrawBonus) {
    for (final member in party.values) {
      // 사용한 카드를 손패에서 제거하고 버린 카드 더미로 이동
      for (final action in member.selectedActions) {
        member.hand.removeWhere((c) => c.id == action.card.id);
        member.discardPile.add(action.card);
      }
      member.selectedActions.clear();
    }

    if (combatStatus == CombatStatus.inProgress) {
      turnNumber++;
      final nextAp = _calculateApForTurn(turnNumber);

      // 드로우 장수 = 기본 1장 + 이전 턴 누적 drawBonus (최대 손패 5장 상한 엄수)
      final drawCount = 1 + previousTurnDrawBonus;

      for (final member in party.values) {
        if (member.isAlive) {
          member.maxAp = nextAp;
          member.currentAp = nextAp;
          _drawCardsForMember(member, drawCount);
        }
      }
    }
  }
}
