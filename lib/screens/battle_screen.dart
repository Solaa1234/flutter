import 'package:flutter/material.dart';

import '../engine/combat_engine.dart';
import '../models/boss_model.dart';
import '../models/card_model.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final Map<JobClass, List<CardModel>> equippedDecks;

  const BattleScreen({super.key, required this.equippedDecks});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late CombatEngine _engine;

  // 현재 조작 중인 캐릭터 (수동 모드 시 전환 가능)
  JobClass _currentControlJob = JobClass.mercenary;

  // 현재 지정된 공격 타겟 부위
  BossPartType _currentTargetPart = BossPartType.body;

  // AI 자동 / Manual 수동 토글 모드
  bool _isAutoAi = true;

  // 전투 동안 달성한 최고 속성 체인 기록
  int _maxChain = 1;

  // 최근 전투 로그 한 줄
  String _lastLogMessage = '전투 개시! 보스의 무기와 방패를 파괴하여 약화시키세요.';

  @override
  void initState() {
    super.initState();
    _engine = CombatEngine(decks: widget.equippedDecks);

    // AI 자동 모드 기본 활성화 시 동료 3명 자동 선택
    if (_isAutoAi) {
      _engine.autoSelectAllAI(playerJob: _currentControlJob);
    }
  }

  Color _getAttributeColor(CardAttribute attr) {
    switch (attr) {
      case CardAttribute.fire:
        return Colors.red.shade700;
      case CardAttribute.wind:
        return Colors.green.shade700;
      case CardAttribute.water:
        return Colors.blue.shade700;
    }
  }

  /// 속성 아이콘/이모지 헬퍼
  String _getAttributeIcon(CardAttribute attr) {
    switch (attr) {
      case CardAttribute.fire:
        return '🔥';
      case CardAttribute.wind:
        return '🌪';
      case CardAttribute.water:
        return '💧';
    }
  }

  /// 보스 부위별 약점 속성 반환
  CardAttribute _getWeaknessAttribute(CardAttribute attr) {
    switch (attr) {
      case CardAttribute.fire:
        return CardAttribute.water; // 불의 약점은 물
      case CardAttribute.water:
        return CardAttribute.wind;  // 물의 약점은 바람
      case CardAttribute.wind:
        return CardAttribute.fire;  // 바람의 약점은 불
    }
  }

  // 타겟 부위 변경
  void _selectTargetPart(BossPartType partType) {
    final part = _engine.boss.getPart(partType);
    if (part.isDestroyed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${part.name}은(는) 이미 파괴되었습니다! 다른 부위를 노리세요.'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
      return;
    }
    setState(() {
      _currentTargetPart = partType;
    });
  }

  // 카드 터치 (선택/해제 토글)
  void _onCardTap(CardModel card) {
    final member = _engine.party[_currentControlJob]!;
    final isAlreadySelected = member.selectedActions.any((a) => a.card.id == card.id);

    setState(() {
      if (isAlreadySelected) {
        _engine.deselectCard(_currentControlJob, card);
        _lastLogMessage = '[${card.name}] 카드 선택이 해제되었습니다.';
      } else {
        // 타겟 부위가 이미 파괴되었다면 본체로 자동 조정
        if (_engine.boss.getPart(_currentTargetPart).isDestroyed) {
          _currentTargetPart = BossPartType.body;
        }

        final success = _engine.selectCard(
          _currentControlJob,
          card,
          targetPart: _currentTargetPart,
        );

        if (success) {
          final targetPart = _engine.boss.getPart(_currentTargetPart);
          final chain = _engine.currentChainCounts[card.attribute] ?? 1;
          final chainMult = CombatEngine.getChainMultiplier(chain);
          final attrMult = CombatEngine.getAttributeMultiplier(
            card.attribute,
            targetPart.attribute,
          );

          String effectSummary = '';
          if (card.isDefenseCard) {
            final val = (card.value * chainMult).round();
            effectSummary = '파티 방어막 +$val ($chain체인)';
          } else if (card.isHealCard) {
            final val = (card.value * chainMult).round();
            effectSummary = '아군 전체 힐 +$val ($chain체인)';
          } else if (card.isDebuffCard) {
            final val = (card.value * chainMult * attrMult).round();
            effectSummary = '마법피해 $val & 공격력 디버프 ($chain체인, ${attrMult}x)';
          } else {
            final val = (card.value * chainMult * attrMult).round();
            effectSummary = '물리피해 $val ($chain체인, ${attrMult}x)';
          }

          if (card.drawBonus > 0) {
            effectSummary += ' | 드로우 +${card.drawBonus}장';
          }

          _lastLogMessage = '[${card.name}] $effectSummary -> ${targetPart.name}';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'AP가 부족합니다! (필요: ${card.cost} / 잔여: ${member.currentAp})',
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.orangeAccent.shade700,
            ),
          );
        }
      }
    });
  }

  // 카드의 세부 효과 모달 다이얼로그
  void _showCardDetailModal(CardModel card) {
    final member = _engine.party[_currentControlJob]!;
    final isSelected = member.selectedActions.any((a) => a.card.id == card.id);
    final targetPart = _engine.boss.getPart(_currentTargetPart);
    final chain = _engine.currentChainCounts[card.attribute] ?? 1;
    final chainMult = CombatEngine.getChainMultiplier(chain);
    final attrMult = CombatEngine.getAttributeMultiplier(
      card.attribute,
      targetPart.attribute,
    );

    // 역할별 세부 효과 설명
    String roleDetailText = '';
    String calculatedEffectText = '';

    if (card.isDefenseCard) {
      final defVal = (card.value * chainMult).round();
      roleDetailText =
          '🛡 [부호 방어 지원]\n체인 배율이 적용된 방어막을 파티 전체에 전개하여, 이번 턴 보스의 강력한 공격 피해를 일괄 경감/흡수합니다.';
      calculatedEffectText =
          '기본 수치 ${card.value} × 체인배율 ${chainMult.toStringAsFixed(1)}x = 파티 방어막 +$defVal DEF';
    } else if (card.isHealCard) {
      final healVal = (card.value * chainMult).round();
      roleDetailText =
          '💖 [가희 전체 치유]\n신성한 치유의 기도로 생존한 파티원 전원의 체력(HP)을 일괄 회복합니다. 체인이 높을수록 힐량이 비례 증가합니다.';
      calculatedEffectText =
          '기본 수치 ${card.value} × 체인배율 ${chainMult.toStringAsFixed(1)}x = 아군 전원 회복 +$healVal HP';
    } else if (card.isDebuffCard) {
      final dmgVal = (card.value * chainMult * attrMult).round();
      final debuffVal = (card.value * 0.20 * chainMult).round();
      roleDetailText =
          '🔮 [도적 마법공격 및 디버프]\n대상 부위에 마법 피해를 입히고, 수치의 20%만큼 보스의 공격력을 즉시 약화시켜 파티의 생존을 지원합니다.';
      calculatedEffectText =
          '기본 ${card.value} × 체인 ${chainMult.toStringAsFixed(1)}x × 상성 ${attrMult.toStringAsFixed(1)}x = 마법피해 $dmgVal DMG\n(보스 공격력 -$debuffVal 약화)';
    } else {
      final dmgVal = (card.value * chainMult * attrMult).round();
      roleDetailText =
          '⚔ [용병 물리 강타]\n대상 부위에 강력한 물리 일격을 가합니다. 약점 속성을 찌르면 2.0배의 폭발적인 상성 데미지를 줍니다.';
      calculatedEffectText =
          '기본 ${card.value} × 체인 ${chainMult.toStringAsFixed(1)}x × 상성 ${attrMult.toStringAsFixed(1)}x = 물리피해 $dmgVal DMG';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getAttributeColor(card.attribute),
              width: 2,
            ),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _getAttributeColor(card.attribute),
                child: Text(
                  '${card.cost}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${card.rarity.isNotEmpty ? "[${card.rarity}] " : ""}${card.attribute.label} 속성 | ${card.job.label} (${card.job.role})',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (card.drawBonus > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade900,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.cyanAccent),
                  ),
                  child: Text(
                    '드로우 +${card.drawBonus}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 역할 및 효과 설명 박스
                  if (card.effect.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700, width: 1),
                      ),
                      child: Text(
                        '📜 카드 효과: ${card.effect}',
                        style: TextStyle(
                          color: Colors.amber.shade100,
                          fontSize: 11,
                        ),
                      ),
                    ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F27),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      roleDetailText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 특수 드로우 보너스 안내 (있는 경우)
                  if (card.drawBonus > 0)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.cyanAccent, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_card, color: Colors.cyanAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '★ 드로우 지원: 이 카드를 내면 다음 턴 시작 시 파티원 전원의 드로우가 +${card.drawBonus}장 증가합니다! (최대 5장 한도)',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 실시간 시너지 계산 박스
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '현재 타겟: ${targetPart.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getAttributeColor(targetPart.attribute),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${targetPart.attribute.label} 속성',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '속성 상성: ${attrMult == 2.0 ? '상극 우세 (2.0x)' : (attrMult == 0.5 ? '역상성 열세 (0.5x)' : '보통 (1.0x)')}',
                              style: TextStyle(
                                color: attrMult == 2.0
                                    ? Colors.amber
                                    : (attrMult == 0.5
                                        ? Colors.redAccent
                                        : Colors.white70),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '동일 속성 체인: $chain체인 (${chainMult}x)',
                              style: TextStyle(
                                color: chain >= 2
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            calculatedEffectText,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Colors.grey.shade700
                    : Colors.amber.shade700,
                foregroundColor: isSelected ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _onCardTap(card);
              },
              icon: Icon(
                isSelected ? Icons.remove_circle_outline : Icons.check_circle_outline,
                size: 16,
              ),
              label: Text(
                isSelected ? '선택 취소' : '이 카드 선택',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // AI 자동 모드 토글
  void _toggleAiMode(bool value) {
    setState(() {
      _isAutoAi = value;
      if (_isAutoAi) {
        // AI 모드로 전환 시 현재 플레이어 직업을 용병으로 리셋하고 동료 3인 AI 자동 선택
        _currentControlJob = JobClass.mercenary;
        _engine.autoSelectAllAI(playerJob: _currentControlJob);
      }
    });
  }

  // 턴 종료 및 일괄 정산 실행
  void _resolveTurn() {
    setState(() {
      if (_isAutoAi) {
        // AI 모드라면 동료 3인의 선택을 최신 상태로 보장
        _engine.autoSelectAllAI(playerJob: _currentControlJob);
      }

      final report = _engine.resolveTurn();
      _lastLogMessage = report.logs.last;

      // 최고 체인 기록 갱신
      for (final chain in report.chainCounts.values) {
        if (chain > _maxChain) {
          _maxChain = chain;
        }
      }

      // 턴 정산 결과 팝업 다이얼로그 표시
      _showTurnReportDialog(report);
    });
  }

  // 턴 정산 결과 다이얼로그 표시 후 전투 종료 체크
  void _showTurnReportDialog(CombatTurnReport report) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: report.status == CombatStatus.victory
                  ? Colors.amber
                  : Colors.grey.shade700,
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Icon(
                report.status == CombatStatus.victory
                    ? Icons.emoji_events
                    : Icons.shield,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                '제 ${report.turnNumber} 턴 정산 결과',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 주요 수치 요약
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          '총 피해량',
                          '${report.totalDamageDealt} DMG',
                          Colors.redAccent,
                        ),
                        _buildSummaryRow(
                          '아군 회복량',
                          '+${report.totalHealingDone} HP',
                          Colors.greenAccent,
                        ),
                        _buildSummaryRow(
                          '부호 방어막',
                          '+${report.partyDefenseBuff} DEF',
                          Colors.blueAccent,
                        ),
                        _buildSummaryRow(
                          '보스 반격 피해',
                          '파티원당 ${report.bossActualDamage} DMG',
                          Colors.orangeAccent,
                        ),
                        _buildSummaryRow(
                          '다음 드로우 보너스',
                          '+${report.turnDrawBonus} 장',
                          Colors.amber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '상세 전투 로그:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.builder(
                      itemCount: report.logs.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Text(
                            report.logs[idx],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기

                // 전투 종료 판정 확인
                if (_engine.combatStatus != CombatStatus.inProgress) {
                  final destroyedParts = (_engine.boss.weapon.isDestroyed ? 1 : 0) +
                      (_engine.boss.shield.isDestroyed ? 1 : 0);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                        isVictory: _engine.combatStatus == CombatStatus.victory,
                        totalTurns: report.turnNumber,
                        destroyedParts: destroyedParts,
                        maxChain: _maxChain,
                        equippedDecks: widget.equippedDecks,
                      ),
                    ),
                  );
                } else {
                  // 다음 턴 AI 동료 자동 선택
                  if (_isAutoAi) {
                    setState(() {
                      _engine.autoSelectAllAI(playerJob: _currentControlJob);
                    });
                  }
                }
              },
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boss = _engine.boss;
    final controlledMember = _engine.party[_currentControlJob]!;
    final chainCounts = _engine.currentChainCounts;
    final pendingDrawBonus = _engine.currentPendingDrawBonus;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24), // 다크 테마 배경
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // [1] 상단 바 (#111116)
            // ==========================================
            Container(
              height: 48,
              color: const Color(0xFF111116),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 턴 수 표시
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'TURN ${_engine.turnNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 보스 광폭화 스택 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: boss.enrageStack > 0
                          ? Colors.red.shade900
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: boss.enrageStack > 0
                            ? Colors.redAccent
                            : Colors.grey.shade700,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥 ', style: TextStyle(fontSize: 11)),
                        Text(
                          '광폭화 ${boss.enrageStack}스택 (+${(boss.enrageStack * 20)}%)',
                          style: TextStyle(
                            color: boss.enrageStack > 0
                                ? Colors.redAccent.shade100
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 중앙 실시간 속성 체인 배지들
                  Row(
                    children: CardAttribute.values.map((attr) {
                      final count = chainCounts[attr] ?? 0;
                      final isChainActive = count >= 2;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isChainActive
                              ? _getAttributeColor(attr)
                              : Colors.black38,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isChainActive
                                ? Colors.white
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${attr.label} $count Chain${isChainActive ? ' (x${CombatEngine.getChainMultiplier(count)})' : ''}',
                          style: TextStyle(
                            color: isChainActive ? Colors.white : Colors.white38,
                            fontWeight: isChainActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // 우측 [AI 자동 / Manual 수동] 실시간 토글
                  Row(
                    children: [
                      Text(
                        _isAutoAi ? 'AI 자동 모드' : 'Manual 수동 모드',
                        style: TextStyle(
                          color: _isAutoAi ? Colors.amber : Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _isAutoAi,
                        activeThumbColor: Colors.amber,
                        inactiveThumbColor: Colors.cyanAccent,
                        inactiveTrackColor: Colors.grey.shade800,
                        onChanged: _toggleAiMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================
            // [2] 상단 중앙 — 보스 영역 (타겟 선택 3개 카드)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A32),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    // 보스 명칭 및 상성 관계도 안내
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pest_control_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              boss.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 속성 상성 관계도 안내 배지
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '상성: 🔥불 > 🌪바람 > 💧물 > 🔥불 (약점 2.0x / 반감 0.5x)',
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '공격할 타겟 부위를 터치하여 지정하세요',
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 3개 부위 카드 ([무기], [본체], [방패]) 가로 나란히 배치
                    Row(
                      children: [
                        // 1. 무기 (Weapon)
                        Expanded(child: _buildBossPartCard(boss.weapon)),
                        const SizedBox(width: 8),
                        // 2. 본체 (Body)
                        Expanded(child: _buildBossPartCard(boss.body)),
                        const SizedBox(width: 8),
                        // 3. 방패 (Shield)
                        Expanded(child: _buildBossPartCard(boss.shield)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // [3] 중단 — 파티원 4인 상태 바
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: JobClass.values.map((job) {
                  final member = _engine.party[job]!;
                  final isCurrentlyControlled = _currentControlJob == job;
                  final isAiControlled = _isAutoAi && job != JobClass.mercenary;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_isAutoAi) {
                          setState(() {
                            _currentControlJob = job;
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentlyControlled
                              ? const Color(0xFF353542)
                              : const Color(0xFF23232B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrentlyControlled
                                ? Colors.amber
                                : member.job.color.withValues(alpha: 0.5),
                            width: isCurrentlyControlled ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 직업 아바타 / 명칭 / 배지
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 8,
                                      backgroundColor: member.job.color,
                                      child: Text(
                                        member.job.label.substring(0, 1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      member.job.label,
                                      style: TextStyle(
                                        color: isCurrentlyControlled
                                            ? Colors.amber
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAiControlled
                                        ? Colors.purple.shade900
                                        : Colors.indigo.shade900,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    isAiControlled ? 'AI' : 'PLAYER',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // HP 바
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: member.hpRatio,
                                minHeight: 6,
                                backgroundColor: Colors.black45,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  member.hpRatio > 0.4
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${member.currentHp} / ${member.maxHp}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // 예약(선택) 카드 미리보기 배지들
                            SizedBox(
                              height: 16,
                              child: Row(
                                children: member.selectedActions.map((action) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getAttributeColor(
                                        action.card.attribute,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      '${action.card.cost}C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 6),

            // ==========================================
            // [4] 하단 — 핸드 & 액션 영역
            // ==========================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // [좌측] AP 표시기 & 추가 드로우 예정 배지
                    Container(
                      width: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A32),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${controlledMember.job.label} AP',
                            style: TextStyle(
                              color: controlledMember.job.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // AP 수치
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber, width: 1.5),
                            ),
                            child: Text(
                              'AP ${controlledMember.currentAp} / ${controlledMember.maxAp}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 다음 턴 드로우 배지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade900,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: pendingDrawBonus > 0
                                    ? Colors.cyanAccent
                                    : Colors.white12,
                              ),
                            ),
                            child: Text(
                              '다음 드로우 +${1 + pendingDrawBonus}',
                              style: TextStyle(
                                color: pendingDrawBonus > 0
                                    ? Colors.cyanAccent
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // [중앙] 최대 5장 고정 슬롯 손패 카드 리스트
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A32),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: List.generate(CombatEngine.maxHandSize, (index) {
                            final card = index < controlledMember.hand.length
                                ? controlledMember.hand[index]
                                : null;

                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                child: card == null
                                    ? _buildEmptyCardSlot()
                                    : _buildHandCard(card, controlledMember),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // [우측] 턴 종료(정산) 대형 버튼 및 전투 로그 배너
                    Container(
                      width: 170,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A32),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          // 턴 종료 (정산) 대형 버튼
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 4,
                              ),
                              onPressed: _resolveTurn,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.flash_on, size: 22),
                                  SizedBox(height: 2),
                                  Text(
                                    '턴 종료 (정산)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // 간단한 전투 로그 배너
                          Expanded(
                            flex: 2,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  _lastLogMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 보스 개별 부위 카드 위젯
  Widget _buildBossPartCard(BossPartModel part) {
    final isSelectedTarget = _currentTargetPart == part.type;
    final isDestroyed = part.isDestroyed;

    return GestureDetector(
      onTap: () => _selectTargetPart(part.type),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelectedTarget
                ? Colors.amber
                : (isDestroyed ? Colors.grey.shade800 : Colors.white24),
            width: isSelectedTarget ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        part.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDestroyed ? Colors.grey : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDestroyed) ...[
                          // 약점 속성 힌트 배지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade900.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.amber.shade700, width: 0.8),
                            ),
                            child: Text(
                              '약점: ${_getAttributeIcon(_getWeaknessAttribute(part.attribute))}${_getWeaknessAttribute(part.attribute).label}',
                              style: TextStyle(
                                color: Colors.amber.shade200,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // 현재 부위 속성 배지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _getAttributeColor(part.attribute),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${_getAttributeIcon(part.attribute)} ${part.attribute.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // HP 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: part.hpRatio,
                    minHeight: 6,
                    backgroundColor: Colors.black45,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      part.hpRatio > 0.4 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HP ${part.currentHp} / ${part.maxHp}',
                      style: const TextStyle(color: Colors.white60, fontSize: 9),
                    ),
                    if (isSelectedTarget && !isDestroyed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'TARGET',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // 파괴 시 오버레이
            if (isDestroyed)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    part.type == BossPartType.weapon
                        ? 'DESTROYED\n(패턴 봉인)'
                        : (part.type == BossPartType.shield
                            ? 'DESTROYED\n(방어막 해제)'
                            : 'DESTROYED'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 빈 카드 슬롯 위젯
  Widget _buildEmptyCardSlot() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Icon(Icons.crop_portrait, color: Colors.white12, size: 24),
      ),
    );
  }

  // 손패 카드 위젯
  Widget _buildHandCard(CardModel card, PartyMemberState member) {
    final isSelected = member.selectedActions.any((a) => a.card.id == card.id);
    final targetPart = _engine.boss.getPart(_currentTargetPart);
    final attrMult = CombatEngine.getAttributeMultiplier(card.attribute, targetPart.attribute);
    final canAfford = isSelected || member.currentAp >= card.cost;

    return GestureDetector(
      onTap: () => _onCardTap(card),
      onLongPress: () => _showCardDetailModal(card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: isSelected ? 0 : 8, bottom: isSelected ? 8 : 0),
        decoration: BoxDecoration(
          color: canAfford ? const Color(0xFF1E1E24) : const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.amber
                : (canAfford
                    ? _getAttributeColor(card.attribute)
                    : Colors.grey.shade800),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // [1] 상단 바: AP 코스트 (소모량) 배지 & 드로우 / 부족 배지
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // AP 코스트(소모량) 배지 - 크고 명확하게 표기
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.amber
                              : (canAfford
                                  ? Colors.amber.shade900
                                  : Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: canAfford
                                ? Colors.amber
                                : Colors.grey.shade600,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 11,
                              color: isSelected ? Colors.black : Colors.amber,
                            ),
                            Text(
                              '${card.cost} AP',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 우측 배지: 드로우 보너스 or AP 부족 알림
                      if (card.drawBonus > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.cyan.shade900,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.cyanAccent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '+${card.drawBonus}D',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (!canAfford)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'AP부족',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // [2] 상단 바로 아래: 현재 타겟 부위에 대한 [실시간 속성 상성 배지]
                  if (card.isAttackCard || card.isDebuffCard) ...[
                    if (attrMult == 2.0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '★ 약점 2.0x',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else if (attrMult == 0.5)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.redAccent, width: 0.8),
                        ),
                        child: const Center(
                          child: Text(
                            '▼ 반감 0.5x',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Center(
                          child: Text(
                            '상성 1.0x',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                  ] else if (card.isDefenseCard) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Center(
                        child: Text(
                          '🛡 파티 방어',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Center(
                        child: Text(
                          '💖 전체 힐',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // [3] 카드 중앙: 속성 엠블럼 태그 & 카드명
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _getAttributeColor(card.attribute),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${_getAttributeIcon(card.attribute)} ${card.attribute.label} 속성',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        card.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // [4] 카드 하단: 기본 수치 및 예상 위력
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      children: [
                        Text(
                          card.isDefenseCard
                              ? '방어 +${card.value}'
                              : (card.isHealCard
                                  ? '치유 +${card.value}'
                                  : (attrMult == 2.0
                                      ? '위력 ${(card.value * 2.0).round()}'
                                      : '위력 ${card.value}')),
                          style: TextStyle(
                            color: attrMult == 2.0
                                ? Colors.amberAccent
                                : Colors.amber.shade200,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (attrMult == 2.0 && (card.isAttackCard || card.isDebuffCard))
                          const Text(
                            '약점 2배 적용',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 8,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 선택됨(READY) 오버레이
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.black, size: 10),
                        SizedBox(width: 1),
                        Text(
                          'READY',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
