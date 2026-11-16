import 'package:flutter/material.dart';

import '../models/card_model.dart';
import 'battle_screen.dart';

class ResultScreen extends StatelessWidget {
  final bool isVictory;
  final int totalTurns;
  final int destroyedParts; // 최대 2 (무기, 방패)
  final int maxChain;
  final Map<JobClass, List<CardModel>> equippedDecks;

  const ResultScreen({
    super.key,
    required this.isVictory,
    required this.totalTurns,
    required this.destroyedParts,
    required this.maxChain,
    required this.equippedDecks,
  });

  /// 턴 최적화 클리어 랭크 계산
  String get rankLabel {
    if (!isVictory) return 'FAIL';
    if (totalTurns <= 5) return 'S RANK';
    if (totalTurns <= 7) return 'A RANK';
    return 'B RANK';
  }

  String get rankDescription {
    if (!isVictory) return '보스 공략 실패 - 파티 전멸';
    if (totalTurns <= 5) return '최단 턴 공략 성공!';
    if (totalTurns <= 7) return '신속 공략 성공!';
    return '보스 토벌 완수!';
  }

  Color get rankColor {
    if (!isVictory) return Colors.redAccent;
    if (totalTurns <= 5) return Colors.amber;
    if (totalTurns <= 7) return Colors.orangeAccent;
    return Colors.lightBlueAccent;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24), // 다크 테마 배경
      appBar: AppBar(
        title: Text(
          isVictory ? '레이드 결과 — 토벌 완료' : '레이드 결과 — 작전 실패',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF111116),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // ==========================================
              // [1] 상단 배너 (VICTORY / DEFEAT + 랭크 배지)
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isVictory
                      ? Colors.amber.shade900.withValues(alpha: 0.25)
                      : Colors.red.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVictory ? Colors.amber : Colors.redAccent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVictory ? Icons.emoji_events : Icons.dangerous,
                          size: 32,
                          color: isVictory ? Colors.amber : Colors.redAccent,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVictory ? 'VICTORY' : 'DEFEAT',
                              style: TextStyle(
                                color: isVictory ? Colors.amber : Colors.redAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              isVictory
                                  ? '빙결룡 키메라를 성공적으로 토벌하고 아발론을 수호했습니다!'
                                  : '보스의 강력한 반격에 파티가 버티지 못했습니다.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 턴 최적화 등급 배지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: rankColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isVictory
                                ? Icons.workspace_premium
                                : Icons.report_problem,
                            color: rankColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                rankLabel,
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                rankDescription,
                                style: TextStyle(
                                  color: rankColor.withValues(alpha: 0.9),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ==========================================
              // [2] 중앙 영역 (좌: 전투 리포트 / 우: 파티 MVP 요약)
              // ==========================================
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [중앙 좌측] 전투 리포트 패널
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A32),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '전투 분석 리포트',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),

                            // 1. 소요 턴 수 (가장 크게 강조)
                            Expanded(
                              flex: 4,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F27),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'TOTAL TURNS',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$totalTurns',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 38,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '제 $totalTurns 턴 정산 종료',
                                      style: TextStyle(
                                        color: Colors.amber.shade200,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // 2. 부위 파괴 달성도 & 3. 최고 속성 체인 (나란히)
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  // 부위 파괴 달성도
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F1F27),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: destroyedParts == 2
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.6)
                                              : Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 20,
                                            color: destroyedParts == 2
                                                ? Colors.greenAccent
                                                : Colors.white70,
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '부위 파괴 달성도',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$destroyedParts / 2 파괴',
                                            style: TextStyle(
                                              color: destroyedParts == 2
                                                  ? Colors.greenAccent
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            destroyedParts == 2
                                                ? '무기/방패 완전 파괴'
                                                : (destroyedParts == 1
                                                    ? '1개 부위 봉인'
                                                    : '부위 파괴 없음'),
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // 최고 속성 체인
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F1F27),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: maxChain >= 4
                                              ? Colors.amber.withValues(alpha: 0.6)
                                              : Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 20,
                                            color: maxChain >= 3
                                                ? Colors.amber
                                                : Colors.cyanAccent,
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '최고 속성 체인',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$maxChain Chain',
                                            style: TextStyle(
                                              color: maxChain >= 3
                                                  ? Colors.amber
                                                  : Colors.cyanAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            maxChain >= 4
                                                ? '체인 위력 x2.0 배율'
                                                : (maxChain == 3
                                                    ? '체인 위력 x1.5 배율'
                                                    : (maxChain == 2
                                                        ? '체인 위력 x1.2 배율'
                                                        : '단일 속성 공격')),
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
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

                    const SizedBox(width: 10),

                    // [중앙 우측] 파티 MVP 요약 패널
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A32),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.group,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '출전 파티 및 리더 카드 요약',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),

                            // 4인 파티 아바타 및 리더 카드 목록
                            Expanded(
                              child: ListView(
                                children: JobClass.values.map((job) {
                                  final deck = equippedDecks[job] ?? [];
                                  final leaderCard =
                                      deck.isNotEmpty ? deck[0] : null;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F1F27),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: job.color.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 직업 아바타
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: job.color,
                                          child: Text(
                                            job.label.substring(0, 1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // 직업명 및 역할
                                        SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                job.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                job.role,
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 6),

                                        // 리더 카드 정보
                                        if (leaderCard != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'LEADER',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          CircleAvatar(
                                            radius: 9,
                                            backgroundColor: _getAttributeColor(
                                              leaderCard.attribute,
                                            ),
                                            child: Text(
                                              '${leaderCard.cost}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              leaderCard.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${leaderCard.value}',
                                            style: TextStyle(
                                              color: Colors.amber.shade200,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ] else
                                          const Text(
                                            '리더 미편성',
                                            style: TextStyle(
                                              color: Colors.white30,
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ==========================================
              // [3] 하단 액션 버튼 ([다시 도전] / [덱 편성(메인)으로])
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 다시 도전 버튼 (동일 덱으로 BattleScreen 재시작)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BattleScreen(
                            equippedDecks: equippedDecks,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text(
                      '다시 도전',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 덱 편성(메인)으로 복귀 버튼
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home, size: 18),
                    label: const Text(
                      '덱 편성(메인)으로',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
