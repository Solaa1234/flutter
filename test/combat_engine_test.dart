import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_test/engine/combat_engine.dart';
import 'package:test_test/models/boss_model.dart';
import 'package:test_test/models/card_model.dart';

void main() {
  group('1. CardModel 및 직업 역할 검증', () {
    test('기본 drawBonus는 0이며 직업별 역할 getter가 올바르게 동작해야 함', () {
      const card = CardModel(
        id: 'test_1',
        name: '테스트 카드',
        cost: 2,
        attribute: CardAttribute.fire,
        job: JobClass.mercenary,
        value: 1000,
      );

      expect(card.drawBonus, 0);
      expect(card.isMercenaryCard, isTrue);
      expect(card.isAttackCard, isTrue);
      expect(card.isDefenseCard, isFalse);
      expect(card.isDebuffCard, isFalse);
      expect(card.isHealCard, isFalse);
      expect(card.hasDrawBonus, isFalse);
    });

    test('부호와 도적 카드 풀에 drawBonus가 1 또는 2가 부여되어야 함', () {
      final wealthyPool = CardModel.getCardPoolByJob(JobClass.wealthy);
      final thiefPool = CardModel.getCardPoolByJob(JobClass.thief);
      final mercenaryPool = CardModel.getCardPoolByJob(JobClass.mercenary);

      final wealthyDrawBonusCards = wealthyPool.where((c) => c.drawBonus > 0).toList();
      final thiefDrawBonusCards = thiefPool.where((c) => c.drawBonus > 0).toList();

      expect(wealthyDrawBonusCards.isNotEmpty, isTrue);
      expect(wealthyDrawBonusCards.any((c) => c.drawBonus == 1), isTrue);
      expect(wealthyDrawBonusCards.any((c) => c.drawBonus == 2), isTrue);

      expect(thiefDrawBonusCards.isNotEmpty, isTrue);
      expect(thiefDrawBonusCards.any((c) => c.drawBonus == 1), isTrue);

      // 용병은 기본 0
      expect(mercenaryPool.every((c) => c.drawBonus == 0), isTrue);
    });

    test('리더 보너스 적용 시 수치가 1.5배로 증가해야 함', () {
      const card = CardModel(
        id: 'leader_1',
        name: '리더 카드',
        cost: 3,
        attribute: CardAttribute.wind,
        job: JobClass.mercenary,
        value: 1000,
      );

      final leaderCard = card.applyLeaderBonus();
      expect(leaderCard.value, 1500);
    });
  });

  group('2. BossModel 부위, 광폭화, 공격력 계산 검증', () {
    late BossModel boss;

    setUp(() {
      boss = BossModel.createDefaultDragon();
    });

    test('보스는 3개 부위(본체, 무기, 방패)를 가지며 속성과 HP가 정상 초기화되어야 함', () {
      expect(boss.body.type, BossPartType.body);
      expect(boss.body.attribute, CardAttribute.water);
      expect(boss.weapon.type, BossPartType.weapon);
      expect(boss.weapon.attribute, CardAttribute.fire);
      expect(boss.shield.type, BossPartType.shield);
      expect(boss.shield.attribute, CardAttribute.wind);

      expect(boss.isWeaponDestroyed, isFalse);
      expect(boss.isShieldDestroyed, isFalse);
      expect(boss.isDefeated, isFalse);
      expect(boss.enrageStack, 0);
    });

    test('무기 파괴 시 보스 공격력 배율이 50%로 대폭 감소해야 함', () {
      final initialAttack = boss.calculateTurnAttack();
      expect(initialAttack, 6000);

      // 무기 파괴
      boss.weapon.takeDamage(boss.weapon.maxHp);
      expect(boss.isWeaponDestroyed, isTrue);

      final reducedAttack = boss.calculateTurnAttack();
      expect(reducedAttack, 3000); // 50% 감소
    });

    test('방패 파괴 시 보스 피해 경감률이 0이 되어야 함', () {
      expect(boss.defenseReduction, 0.20);

      boss.shield.takeDamage(boss.shield.maxHp);
      expect(boss.isShieldDestroyed, isTrue);
      expect(boss.defenseReduction, 0.0);
    });

    test('광폭화 스택 증가 시 공격력 배율이 중첩되어야 함', () {
      boss.increaseEnrageStack(); // 1스택 (+20%)
      expect(boss.attackMultiplier, 1.20);
      expect(boss.calculateTurnAttack(), 7200);

      boss.increaseEnrageStack(); // 2스택 (+40%)
      expect(boss.attackMultiplier, 1.40);
      expect(boss.calculateTurnAttack(), 8400);
    });

    test('본체 HP가 0이 되면 보스 토벌 (isDefeated == true) 판정이어야 함', () {
      boss.body.takeDamage(boss.body.maxHp);
      expect(boss.body.isDestroyed, isTrue);
      expect(boss.isDefeated, isTrue);
    });
  });

  group('3. CombatEngine 전투 로직 검증', () {
    late Map<JobClass, List<CardModel>> testDecks;
    late CombatEngine engine;

    setUp(() {
      testDecks = {};
      for (final job in JobClass.values) {
        testDecks[job] = CardModel.getCardPoolByJob(job).take(10).toList();
      }
      engine = CombatEngine(decks: testDecks, random: Random(42));
    });

    test('전투 초기화: 0번 Leader 카드 1.5배 수치 반영 및 1턴 5장 드로우', () {
      for (final job in JobClass.values) {
        final member = engine.party[job]!;
        expect(member.hand.length, 5);
        expect(member.drawPile.length, 5);
        expect(member.discardPile.length, 0);
        expect(member.currentAp, 3);
        expect(member.maxAp, 3);

        // Leader 카드가 덱 어딘가에 1.5배로 존재해야 함
        final allCards = [...member.hand, ...member.drawPile];
        final originalLeader = testDecks[job]![0];
        final expectedLeaderValue = (originalLeader.value * 1.5).round();
        expect(allCards.any((c) => c.value == expectedLeaderValue), isTrue);
      }
    });

    test('속성 상성 배율: 불 > 바람 > 물 > 불 (상극 2.0배, 역상성 0.5배)', () {
      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.fire, CardAttribute.wind),
        2.0,
      );
      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.wind, CardAttribute.water),
        2.0,
      );
      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.water, CardAttribute.fire),
        2.0,
      );

      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.wind, CardAttribute.fire),
        0.5,
      );
      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.water, CardAttribute.wind),
        0.5,
      );
      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.fire, CardAttribute.water),
        0.5,
      );

      expect(
        CombatEngine.getAttributeMultiplier(CardAttribute.fire, CardAttribute.fire),
        1.0,
      );
    });

    test('체인 배율 검증: 2체인 1.2, 3체인 1.5, 4체인 2.0', () {
      expect(CombatEngine.getChainMultiplier(1), 1.0);
      expect(CombatEngine.getChainMultiplier(2), 1.2);
      expect(CombatEngine.getChainMultiplier(3), 1.5);
      expect(CombatEngine.getChainMultiplier(4), 2.0);
      expect(CombatEngine.getChainMultiplier(5), 2.0);
    });

    test('AP 한도 초과 선택 방지 및 카드 선택/취소', () {
      final merc = engine.party[JobClass.mercenary]!;
      expect(merc.currentAp, 3);

      final card = merc.hand.firstWhere((c) => c.cost <= 3);
      final success = engine.selectCard(JobClass.mercenary, card);
      expect(success, isTrue);
      expect(merc.currentAp, 3 - card.cost);
      expect(merc.selectedActions.length, 1);

      // 잔여 AP를 초과하는 고코스트 카드는 선택 불가
      final tooExpensive = merc.hand.firstWhere(
        (c) => c.cost > merc.currentAp,
        orElse: () => card,
      );
      if (tooExpensive != card) {
        final fail = engine.selectCard(JobClass.mercenary, tooExpensive);
        expect(fail, isFalse);
      }

      // 카드 선택 취소 시 AP 복구
      engine.deselectCard(JobClass.mercenary, card);
      expect(merc.currentAp, 3);
      expect(merc.selectedActions.isEmpty, isTrue);
    });

    test('AI 자동 선택 로직: 가희, 부호, 도적 규칙 검증', () {
      // 1. 도적 AI: AP 내에서 고코스트/고수치 선택
      engine.autoSelectForJob(JobClass.thief);
      final thief = engine.party[JobClass.thief]!;
      expect(thief.selectedActions.isNotEmpty, isTrue);

      // 2. 가희 AI: 아군 체력이 70% 이하일 때 힐 카드 우선 선택
      final mercenary = engine.party[JobClass.mercenary]!;
      mercenary.currentHp = (mercenary.maxHp * 0.5).round(); // 50%로 체력 감소
      engine.autoSelectForJob(JobClass.bard);
      final bard = engine.party[JobClass.bard]!;
      expect(bard.selectedActions.isNotEmpty, isTrue);
      final bardSelectedCards = bard.selectedActions.map((a) => a.card).toList();
      final healCardsInHand = bard.hand.where((c) => c.isHealCard).toList();
      if (healCardsInHand.isNotEmpty) {
        expect(bardSelectedCards.any((c) => c.isHealCard), isTrue);
      }

      // 3. 부호 AI: 아군 손패가 3장 이하일 때 드로우 보너스 또는 방어 카드 우선
      mercenary.hand.removeRange(3, mercenary.hand.length); // 손패를 3장으로 줄임
      engine.autoSelectForJob(JobClass.wealthy);
      final wealthy = engine.party[JobClass.wealthy]!;
      expect(wealthy.selectedActions.isNotEmpty, isTrue);
    });

    test('턴 정산 (resolveTurn): 행동 정산, 보스 반격, 광폭화 스택 증가, 다음 턴 4 AP 충전', () {
      engine.autoSelectAllAI();
      final report = engine.resolveTurn();

      expect(report.turnNumber, 1);
      expect(report.status, CombatStatus.inProgress);
      expect(engine.turnNumber, 2);
      expect(engine.boss.enrageStack, 1);

      // 2턴 AP는 4여야 함
      for (final member in engine.party.values) {
        expect(member.currentAp, 4);
        expect(member.maxAp, 4);
        // 손패는 상한 5장을 초과하지 않아야 함
        expect(member.hand.length <= CombatEngine.maxHandSize, isTrue);
      }
    });

    test('덱 소진 시 버린 카드 더미 재셔플 드로우 검증', () {
      final merc = engine.party[JobClass.mercenary]!;
      // 손패를 모두 버린 더미로 이동시키고 drawPile을 비움
      merc.discardPile.addAll(merc.hand);
      merc.hand.clear();
      merc.discardPile.addAll(merc.drawPile);
      merc.drawPile.clear();

      // 드로우 함수 호출 (5장)
      engine.party[JobClass.mercenary]!.currentAp = 3;
      // resolveTurn을 위해 각 직업 카드 선택
      engine.autoSelectAllAI();
      engine.resolveTurn();

      // 버린 더미가 다시 덱으로 셔플되어 손패로 들어왔는지 확인
      expect(merc.hand.isNotEmpty, isTrue);
    });
  });
}
