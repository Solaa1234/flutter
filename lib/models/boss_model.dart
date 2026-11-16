import 'card_model.dart';

/// 보스 부위 종류 (본체, 무기, 방패)
enum BossPartType {
  body('본체'),
  weapon('무기'),
  shield('방패');

  final String label;
  const BossPartType(this.label);
}

/// 보스 개별 부위 모델
class BossPartModel {
  final BossPartType type;
  final String name;
  final CardAttribute attribute;
  final int maxHp;
  int currentHp;
  bool isDestroyed;

  BossPartModel({
    required this.type,
    required this.name,
    required this.attribute,
    required this.maxHp,
    int? currentHp,
    this.isDestroyed = false,
  }) : currentHp = (currentHp ?? maxHp).clamp(0, maxHp);

  /// 피해를 적용하고 파괴 여부를 갱신합니다. 실제 입힌 피해량을 반환합니다.
  int takeDamage(int damage) {
    if (isDestroyed || damage <= 0) return 0;

    final actualDamage = damage.clamp(0, currentHp);
    currentHp -= damage;
    if (currentHp <= 0) {
      currentHp = 0;
      isDestroyed = true;
    }
    return actualDamage;
  }

  /// HP 잔여 비율 (0.0 ~ 1.0)
  double get hpRatio => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  BossPartModel copyWith({
    BossPartType? type,
    String? name,
    CardAttribute? attribute,
    int? maxHp,
    int? currentHp,
    bool? isDestroyed,
  }) {
    return BossPartModel(
      type: type ?? this.type,
      name: name ?? this.name,
      attribute: attribute ?? this.attribute,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      isDestroyed: isDestroyed ?? this.isDestroyed,
    );
  }

  @override
  String toString() => '$name [속성: ${attribute.label}, HP: $currentHp/$maxHp, 파괴: $isDestroyed]';
}

/// 3개 부위(본체, 무기, 방패)를 가진 보스 모델
class BossModel {
  final String name;
  final BossPartModel body;
  final BossPartModel weapon;
  final BossPartModel shield;
  int enrageStack;
  final int baseAttack;

  BossModel({
    required this.name,
    required this.body,
    required this.weapon,
    required this.shield,
    this.enrageStack = 0,
    this.baseAttack = 6000,
  });

  /// 보스의 모든 부위 리스트
  List<BossPartModel> get parts => [body, weapon, shield];

  /// 아직 파괴되지 않은 부위 리스트
  List<BossPartModel> get activeParts => parts.where((p) => !p.isDestroyed).toList();

  /// 특정 부위 조회
  BossPartModel getPart(BossPartType type) {
    switch (type) {
      case BossPartType.body:
        return body;
      case BossPartType.weapon:
        return weapon;
      case BossPartType.shield:
        return shield;
    }
  }

  /// 무기 파괴 여부 (무기 파괴 시 공격력 대폭 감소 및 특수 패턴 봉인)
  bool get isWeaponDestroyed => weapon.isDestroyed;

  /// 방패 파괴 여부 (방패 파괴 시 보스 방어막/버프 봉인)
  bool get isShieldDestroyed => shield.isDestroyed;

  /// 본체 HP가 0이 되면 보스 토벌 (전투 승리)
  bool get isDefeated => body.isDestroyed || body.currentHp <= 0;

  /// 턴 종료 시 광폭화 스택 중첩 증가
  void increaseEnrageStack() {
    enrageStack++;
  }

  /// 보스 공격력 배율 (기본 1.0 + 광폭화 스택당 +20% 증가, 무기 파괴 시 50% 대폭 감소)
  double get attackMultiplier {
    double mult = 1.0 + (enrageStack * 0.20);
    if (isWeaponDestroyed) {
      mult *= 0.50; // 무기 파괴 시 공격력 50%로 대폭 감소
    }
    return mult;
  }

  /// 보스 방어막 피해 경감율 (방패 파괴 시 0%, 방패 유지 시 20% 경감)
  double get defenseReduction {
    if (isShieldDestroyed) {
      return 0.0;
    }
    return 0.20; // 방패 유지 중 20% 데미지 감소 버프
  }

  /// 현재 턴 보스 공격 데미지 계산
  int calculateTurnAttack() {
    return (baseAttack * attackMultiplier).round();
  }

  /// 기본 레이드 보스 (빙결룡 키메라) 생성 팩토리
  factory BossModel.createDefaultDragon() {
    return BossModel(
      name: '빙결룡 키메라',
      baseAttack: 6000,
      enrageStack: 0,
      body: BossPartModel(
        type: BossPartType.body,
        name: '본체 [빙결룡]',
        attribute: CardAttribute.water, // 물 속성
        maxHp: 60000,
      ),
      weapon: BossPartModel(
        type: BossPartType.weapon,
        name: '화염 날개 [무기]',
        attribute: CardAttribute.fire, // 불 속성
        maxHp: 25000,
      ),
      shield: BossPartModel(
        type: BossPartType.shield,
        name: '질풍 갑각 [방패]',
        attribute: CardAttribute.wind, // 바람 속성
        maxHp: 25000,
      ),
    );
  }

  @override
  String toString() => '$name (광폭화 $enrageStack스택) | 본체:${body.currentHp}/${body.maxHp}, 무기:${weapon.currentHp}/${weapon.maxHp}(파괴:$isWeaponDestroyed), 방패:${shield.currentHp}/${shield.maxHp}(파괴:$isShieldDestroyed)';
}
