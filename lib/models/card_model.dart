import 'package:flutter/material.dart';

import 'all_cards_data.dart';

enum JobClass {
  mercenary('용병', '딜러', Colors.red),
  wealthy('부호', '탱커/버퍼', Colors.blue),
  thief('도적', '디버퍼/딜러', Colors.purple),
  bard('가희', '힐러', Colors.green);

  final String label;
  final String role;
  final Color color;

  const JobClass(this.label, this.role, this.color);

  // 직업별 역할 구분 헬퍼 getter
  bool get isMercenary => this == JobClass.mercenary;
  bool get isWealthy => this == JobClass.wealthy;
  bool get isThief => this == JobClass.thief;
  bool get isBard => this == JobClass.bard;

  // 역할 특성 getter
  bool get isAttacker => this == JobClass.mercenary;
  bool get isDefender => this == JobClass.wealthy;
  bool get isDebuffer => this == JobClass.thief;
  bool get isHealer => this == JobClass.bard;
}

enum CardAttribute {
  fire('불'),
  wind('바람'),
  water('물');

  final String label;
  const CardAttribute(this.label);
}

class CardModel {
  final String id;
  final String name;
  final int cost;
  final CardAttribute attribute;
  final JobClass job;
  final int value; // 공격력 / 방어력 / 힐량 수치
  final int drawBonus; // 추가 드로우 수치 (기본값 0)
  final String rarity; // 카드 레어도 (예: UR, SR, R, ☆2 등)
  final String effect; // 카드 상세 효과
  final String? fullTitle; // 원본 타이틀명
  final bool isCommon; // 전 직업 공용 카드 여부

  /// 최대 덱 편성 코스트 (10장 덱 기준 35 CP)
  static const int maxDeckCost = 35;

  /// 등급별 덱 편성 코스트 (1번 방안: UR 10, SR 3, R 2, ☆2 1)
  int get deckCost {
    switch (rarity) {
      case 'UR':
        return 10;
      case 'SR':
        return 3;
      case 'R':
        return 2;
      case '☆2':
        return 1;
      default:
        return 1;
    }
  }

  const CardModel({
    required this.id,
    required this.name,
    required this.cost,
    required this.attribute,
    required this.job,
    required this.value,
    this.drawBonus = 0,
    this.rarity = 'R',
    this.effect = '',
    this.fullTitle,
    this.isCommon = false,
  });

  // JSON 맵핑 팩토리
  factory CardModel.fromJson(Map<String, dynamic> json, {JobClass job = JobClass.mercenary, bool isCommon = false}) {
    final attrStr = json['attribute'] as String? ?? '화';
    CardAttribute attr;
    if (attrStr.contains('풍') || attrStr.contains('바람')) {
      attr = CardAttribute.wind;
    } else if (attrStr.contains('빙') || attrStr.contains('수') || attrStr.contains('물') || attrStr.contains('암')) {
      attr = CardAttribute.water;
    } else {
      attr = CardAttribute.fire;
    }

    final cardIsCommon = isCommon || (json['isCommon'] == true) || (json['job'] == 'common');

    return CardModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 3,
      attribute: attr,
      job: job,
      value: (json['value'] as num?)?.toInt() ?? 5000,
      drawBonus: (json['drawBonus'] as num?)?.toInt() ?? 0,
      rarity: json['rarity'] as String? ?? 'R',
      effect: json['effect'] as String? ?? '',
      fullTitle: json['full_name'] as String?,
      isCommon: cardIsCommon,
    );
  }

  // 직업별 역할 구분 헬퍼 getter (공용 카드는 모든 직업 지원)
  bool get isMercenaryCard => job == JobClass.mercenary || isCommon;
  bool get isWealthyCard => job == JobClass.wealthy || isCommon;
  bool get isThiefCard => job == JobClass.thief || isCommon;
  bool get isBardCard => job == JobClass.bard || isCommon;

  // 카드 역할별 동작 구분 헬퍼 getter
  // 용병=공격, 부호=방어/드로우, 도적=마법공격/디버프, 가희=아군전체회복, 공용=지원/디버프
  bool get isAttackCard => job == JobClass.mercenary && !isCommon;
  bool get isDefenseCard => job == JobClass.wealthy && !isCommon;
  bool get isDebuffCard => job == JobClass.thief || isCommon;
  bool get isHealCard => job == JobClass.bard && !isCommon;
  bool get hasDrawBonus => drawBonus > 0;

  /// Leader 카드 1.5배 보너스 적용
  CardModel applyLeaderBonus() {
    return CardModel(
      id: id,
      name: name,
      cost: cost,
      attribute: attribute,
      job: job,
      value: (value * 1.5).round(),
      drawBonus: drawBonus,
      rarity: rarity,
      effect: effect,
      fullTitle: fullTitle,
      isCommon: isCommon,
    );
  }

  CardModel copyWith({
    String? id,
    String? name,
    int? cost,
    CardAttribute? attribute,
    JobClass? job,
    int? value,
    int? drawBonus,
    String? rarity,
    String? effect,
    String? fullTitle,
    bool? isCommon,
  }) {
    return CardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      attribute: attribute ?? this.attribute,
      job: job ?? this.job,
      value: value ?? this.value,
      drawBonus: drawBonus ?? this.drawBonus,
      rarity: rarity ?? this.rarity,
      effect: effect ?? this.effect,
      fullTitle: fullTitle ?? this.fullTitle,
      isCommon: isCommon ?? this.isCommon,
    );
  }

  @override
  String toString() => '$name [레어도:$rarity, 코스트:$cost, 속성:${attribute.label}, 직업:${job.label}, 수치:$value, 드로우+$drawBonus, 공용:$isCommon]';

  /// 직업별 카드 풀(Pool) 반환 데이터 (해당 직업 카드 + 전 직업 사용 가능한 공용 카드)
  static List<CardModel> getCardPoolByJob(JobClass job) {
    List<Map<String, dynamic>> rawJobCards;
    switch (job) {
      case JobClass.mercenary:
        rawJobCards = mercenaryCardsData;
        break;
      case JobClass.wealthy:
        rawJobCards = wealthyCardsData;
        break;
      case JobClass.thief:
        rawJobCards = thiefCardsData;
        break;
      case JobClass.bard:
        rawJobCards = bardCardsData;
        break;
    }

    final jobCards = rawJobCards.map((d) => CardModel.fromJson(d, job: job)).toList();
    final commonCards = commonCardsData.map((d) => CardModel.fromJson(d, job: job, isCommon: true)).toList();

    return [...jobCards, ...commonCards];
  }

  /// 덱 편성 코스트(최대 35 CP)와 10장을 충족하는 최적의 추천 덱 자동 구성 (UR 최대 1~2장)
  static List<CardModel> buildRecommendedDeck(List<CardModel> pool) {
    final urs = pool.where((c) => c.rarity == 'UR').toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final nonUrs = pool.where((c) => c.rarity != 'UR').toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<CardModel>? bestDeck;
    int bestValue = -1;

    for (final urCount in [2, 1, 0]) {
      if (urs.length < urCount) continue;
      final selectedUr = urs.take(urCount).toList();
      final remCards = 10 - urCount;
      final urCost = selectedUr.fold(0, (sum, c) => sum + c.deckCost);
      final remCost = maxDeckCost - urCost;

      // DP: key = (count * 100 + cost)
      var dp = <int, _RecommendedDeckState>{
        0: const _RecommendedDeckState(0, []),
      };

      for (final card in nonUrs) {
        final cCost = card.deckCost;
        final cVal = card.value;
        final nextDp = Map<int, _RecommendedDeckState>.from(dp);

        for (final entry in dp.entries) {
          final cnt = entry.key ~/ 100;
          final cost = entry.key % 100;
          if (cnt < remCards && cost + cCost <= remCost) {
            final nextKey = (cnt + 1) * 100 + (cost + cCost);
            final nextVal = entry.value.value + cVal;
            if (!nextDp.containsKey(nextKey) || nextDp[nextKey]!.value < nextVal) {
              nextDp[nextKey] = _RecommendedDeckState(nextVal, [...entry.value.cards, card]);
            }
          }
        }
        dp = nextDp;
      }

      final candidates = dp.entries.where((e) => (e.key ~/ 100) == remCards).toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.value.value.compareTo(a.value.value));
        final bestCandidate = candidates.first;
        final totalValue = (bestCandidate.value.value + selectedUr.fold<int>(0, (sum, c) => sum + c.value));
        if (totalValue > bestValue) {
          bestValue = totalValue;
          bestDeck = [...selectedUr, ...bestCandidate.value.cards];
        }
      }
    }

    return bestDeck ?? pool.take(10).toList();
  }
}

class _RecommendedDeckState {
  final int value;
  final List<CardModel> cards;
  const _RecommendedDeckState(this.value, this.cards);
}
