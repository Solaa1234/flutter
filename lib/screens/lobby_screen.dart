import 'package:flutter/material.dart';

import '../models/card_model.dart';
import 'boss_selection_screen.dart';
import 'raid_deck_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // 로비에서 관리하는 기본 덱 상태 (직업별 10장)
  final Map<JobClass, List<CardModel>> _cardPools = {};
  final Map<JobClass, List<CardModel>> _equippedDecks = {};

  @override
  void initState() {
    super.initState();

    // 카드 풀 초기화
    for (var job in JobClass.values) {
      final pool = CardModel.getCardPoolByJob(job);
      _cardPools[job] = pool;
      _equippedDecks[job] = CardModel.buildRecommendedDeck(pool);
    }

    // 퀘스트 버튼 글로우 애니메이션
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1226),
      body: SafeArea(
        child: Stack(
          children: [
            // ── 배경 그라디언트 ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1226),
                    Color(0xFF0D1B3E),
                    Color(0xFF1A1226),
                  ],
                ),
              ),
            ),

            // ── 메인 레이아웃 ──
            Column(
              children: [
                // 상단 HUD 바
                _buildTopHud(),

                // 중앙 영역
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 왼쪽: 캐릭터 아트 영역
                      _buildCharacterArea(),

                      // 오른쪽: 퀘스트 / 아레나 버튼
                      _buildRightButtons(),
                    ],
                  ),
                ),

                // 하단 네비게이션 바
                _buildBottomNav(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 상단 HUD
  // ─────────────────────────────────────────────
  Widget _buildTopHud() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF3A2060), width: 1),
        ),
      ),
      child: Row(
        children: [
          _hudBadge('LV', '149', Colors.amber),
          const SizedBox(width: 10),
          _hudBadge('AP', '94 / 94', Colors.green),
          const SizedBox(width: 10),
          _hudBadge('G', '2.2K', Colors.yellow.shade700),
          const SizedBox(width: 10),
          _hudBadge('FP', '37', Colors.cyan),
          const Spacer(),
          _menuButton(),
        ],
      ),
    );
  }

  Widget _hudBadge(String prefix, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prefix,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _menuButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF3A2060),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('MENU',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 왼쪽 캐릭터 영역
  // ─────────────────────────────────────────────
  Widget _buildCharacterArea() {
    return Expanded(
      flex: 5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 환경 광원 효과 (방사형 그라디언트)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 0.4),
                  radius: 0.8,
                  colors: [
                    Color(0x44FF8C00),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 캐릭터 플레이스홀더 (실제 에셋 연결 시 Image.asset으로 교체)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 160,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF5A3A7A), Color(0xFF2A1A4A)],
                  ),
                  border: Border.all(
                    color: Colors.purple.shade300.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: 80, color: Color(0xFFDDCCFF)),
                    SizedBox(height: 8),
                    Text('캐릭터',
                        style: TextStyle(color: Colors.white60, fontSize: 13)),
                    Text('(에셋 교체 예정)',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 하단 타이틀
              const Text(
                '괴리성 밀리언 아서',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.orange, blurRadius: 8),
                  ],
                ),
              ),
              const Text(
                '메뉴를 선택해 주세요',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 오른쪽 버튼 영역 (퀘스트 / 아레나)
  // ─────────────────────────────────────────────
  Widget _buildRightButtons() {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 퀘스트 버튼 (메인 행동 버튼) ──
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.orange.withValues(alpha: _glowAnim.value * 0.7),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFD84000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.orange, width: 1.5),
                  ),
                ),
                onPressed: _onQuestPressed,
                child: const Column(
                  children: [
                    Icon(Icons.map_outlined, size: 26),
                    SizedBox(height: 4),
                    Text('퀘스트',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── 아레나 버튼 (준비 중 표시) ──
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1A3A6A),
                foregroundColor: Colors.white60,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side:
                      BorderSide(color: Colors.blue.shade800, width: 1.5),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('아레나: 랭크 매칭 준비 중입니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Column(
                children: [
                  Icon(Icons.emoji_events_outlined, size: 24),
                  SizedBox(height: 4),
                  Text('아레나',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('랭크 매칭 준비 중',
                      style: TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
            ),

            const Spacer(),

            // ── 현재 덱 간단 요약 ──
            _buildDeckSummaryCard(),
          ],
        ),
      ),
    );
  }

  // 로비 오른쪽 하단의 현재 덱 요약
  Widget _buildDeckSummaryCard() {
    final totalCards =
        _equippedDecks.values.fold(0, (sum, deck) => sum + deck.length);
    final allReady = _equippedDecks.values.every(
      (d) => d.length == 10 && d.fold(0, (sum, c) => sum + c.deckCost) <= CardModel.maxDeckCost,
    );

    return GestureDetector(
      onTap: _openDeckEdit,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: allReady
                ? Colors.green.shade700
                : Colors.orange.shade700,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.style_outlined,
              color:
                  allReady ? Colors.greenAccent : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('현재 덱',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(
                    '$totalCards / 40장  ${allReady ? '✓ 편성 완료' : '편성 필요'}',
                    style: TextStyle(
                      color: allReady ? Colors.greenAccent : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 하단 네비게이션
  // ─────────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = [
      (Icons.home, '거점'),
      (Icons.flash_on, '배틀'),
      (Icons.person, '아서'),
      (Icons.style, '카드'),
      (Icons.people, '프렌드'),
      (Icons.shopping_bag, '샵'),
    ];

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        border: const Border(
          top: BorderSide(color: Color(0xFF3A2060), width: 1),
        ),
      ),
      child: Row(
        children: navItems.map((item) {
          final isActive = item.$2 == '거점';
          return Expanded(
            child: InkWell(
              onTap: () {
                if (item.$2 == '카드') {
                  _openDeckEdit();
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.$1,
                    size: 20,
                    color: isActive
                        ? Colors.amber
                        : Colors.white38,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: isActive ? Colors.amber : Colors.white38,
                      fontSize: 10,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 16,
                      height: 2,
                      color: Colors.amber,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 액션
  // ─────────────────────────────────────────────

  /// 퀘스트 버튼 → 보스 선택 화면으로 이동
  void _onQuestPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BossSelectionScreen(),
      ),
    );
  }


  /// 하단 카드 탭 / 덱 요약 → 기본 덱 편성 화면으로 이동
  void _openDeckEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RaidDeckScreen(
          initialDecks: Map.from(_equippedDecks),
          isFromLobby: true,
        ),
      ),
    ).then((updatedDecks) {
      if (updatedDecks != null) {
        setState(() {
          _equippedDecks.addAll(updatedDecks as Map<JobClass, List<CardModel>>);
        });
      }
    });
  }
}
