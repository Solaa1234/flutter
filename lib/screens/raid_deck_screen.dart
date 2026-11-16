import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/card_model.dart';
import 'battle_screen.dart';

class RaidDeckScreen extends StatefulWidget {
  /// 로비에서 넘어온 덱 상태 (없으면 기본값으로 초기화)
  final Map<JobClass, List<CardModel>>? initialDecks;

  /// 로비의 덱 편집 메뉴에서 진입했는지 여부 (true일 경우 '레이드 시작' 대신 '돌아가기' 제공)
  final bool isFromLobby;

  const RaidDeckScreen({
    super.key,
    this.initialDecks,
    this.isFromLobby = false,
  });

  @override
  State<RaidDeckScreen> createState() => _RaidDeckScreenState();
}

class _RaidDeckScreenState extends State<RaidDeckScreen> {
  JobClass _currentJob = JobClass.mercenary;

  // 직업별 30장 카드의 전체 풀
  final Map<JobClass, List<CardModel>> _cardPools = {};

  // 직업별 현재 장착 중인 10장 덱 카드 리스트 (순서 보장: 0번 index가 Leader)
  final Map<JobClass, List<CardModel>> _equippedDecks = {};

  @override
  void initState() {
    super.initState();
    // 카드 풀 초기화
    for (var job in JobClass.values) {
      final pool = CardModel.getCardPoolByJob(job);
      _cardPools[job] = pool;
      // 로비에서 넘어온 덱이 있으면 사용, 없으면 추천 덱(코스트 35 CP 준수)
      _equippedDecks[job] = widget.initialDecks?[job] ?? CardModel.buildRecommendedDeck(pool);
    }
  }

  // 현재 직업 덱의 편성 코스트 합산
  int _currentDeckCost(JobClass job) {
    return (_equippedDecks[job] ?? []).fold(0, (sum, c) => sum + c.deckCost);
  }

  // 편성 코스트 초과 여부
  bool _isDeckCostOver(JobClass job) {
    return _currentDeckCost(job) > CardModel.maxDeckCost;
  }

  // 자동 추천 덱 (코스트 35 CP 이하, 수치 최대화)
  void _autoFillDeck(JobClass job) {
    setState(() {
      _equippedDecks[job] = CardModel.buildRecommendedDeck(_cardPools[job]!);
    });
  }

  // 카드 교체/선택/해제 모달 팝업
  void _showCardSwapModal(int slotIndex) {
    final pool = _cardPools[_currentJob]!;
    final currentDeck = _equippedDecks[_currentJob]!;
    final ScrollController modalScrollController = ScrollController();
    CardAttribute? selectedFilter; // 속성 필터
    String? selectedRarityFilter; // 등급 필터

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 속성 및 등급으로 필터링된 카드 목록
            final filteredCards = pool.where((c) {
              if (selectedFilter != null && c.attribute != selectedFilter) {
                return false;
              }
              if (selectedRarityFilter != null && c.rarity != selectedRarityFilter) {
                return false;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        slotIndex == 0
                            ? 'LEADER 카드 교체 (필수 1장)'
                            : (slotIndex < currentDeck.length
                                ? '덱 카드 교체/해제 (슬롯 #${slotIndex + 1})'
                                : '덱 카드 추가 (슬롯 #${slotIndex + 1})'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 8),

                  // 속성 필터 칩 바
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          '속성 필터: ',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        ChoiceChip(
                          label: const Text('전체'),
                          selected: selectedFilter == null,
                          onSelected: (val) {
                            setModalState(() => selectedFilter = null);
                          },
                          selectedColor: Colors.amber,
                          labelStyle: TextStyle(
                            color: selectedFilter == null ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...CardAttribute.values.map((attr) {
                          final isSelected = selectedFilter == attr;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(attr.label),
                              selected: isSelected,
                              onSelected: (val) {
                                setModalState(() => selectedFilter = val ? attr : null);
                              },
                              selectedColor: _getAttributeColor(attr),
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 등급(레어도) 필터 칩 바
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          '등급 필터: ',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        ChoiceChip(
                          label: const Text('전체 등급'),
                          selected: selectedRarityFilter == null,
                          onSelected: (val) {
                            setModalState(() => selectedRarityFilter = null);
                          },
                          selectedColor: Colors.tealAccent.shade700,
                          labelStyle: TextStyle(
                            color: selectedRarityFilter == null ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ...const ['UR', 'SR', 'R', '☆2'].map((rarity) {
                          final isSelected = selectedRarityFilter == rarity;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(rarity),
                              selected: isSelected,
                              onSelected: (val) {
                                setModalState(() => selectedRarityFilter = val ? rarity : null);
                              },
                              selectedColor: _getRarityChipColor(rarity),
                              labelStyle: TextStyle(
                                color: isSelected && rarity == 'UR'
                                    ? Colors.amberAccent
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '(${filteredCards.length}장)',
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 카드 리스트 (마우스/터치 드래그 스크롤 허용 및 스크롤바 제공)
                  Expanded(
                    child: filteredCards.isEmpty
                        ? const Center(
                            child: Text(
                              '선택한 필터 조건에 해당하는 카드가 없습니다.',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          )
                        : ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: Scrollbar(
                        controller: modalScrollController,
                        thumbVisibility: true,
                        radius: const Radius.circular(4),
                        child: ListView.builder(
                          controller: modalScrollController,
                          itemCount: filteredCards.length,
                          itemBuilder: (context, index) {
                            final card = filteredCards[index];
                            final isEquipped = currentDeck.any((c) => c.id == card.id);
                            final equippedIndex = currentDeck.indexWhere((c) => c.id == card.id);
                            final isCurrentSlotCard = slotIndex < currentDeck.length && currentDeck[slotIndex].id == card.id;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              tileColor: isCurrentSlotCard
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : (isEquipped ? Colors.white10 : Colors.transparent),
                              leading: CircleAvatar(
                                backgroundColor: _getAttributeColor(card.attribute),
                                child: Text(
                                  '${card.cost}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  if (card.rarity.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: card.rarity == 'UR'
                                            ? Colors.amber.shade900
                                            : (card.rarity == 'SR' ? Colors.purple.shade900 : Colors.blueGrey.shade800),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: card.rarity == 'UR' ? Colors.amberAccent : Colors.white24,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        card.rarity,
                                        style: TextStyle(
                                          color: card.rarity == 'UR' ? Colors.amberAccent : Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (card.isCommon)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade800,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        '공용',
                                        style: TextStyle(
                                          color: Colors.tealAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      card.name,
                                      style: TextStyle(
                                        color: isEquipped ? Colors.amber : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (card.drawBonus > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.cyan.shade900,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '+${card.drawBonus}D',
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '수치: ${card.value} | 속성: ${card.attribute.label}${isEquipped ? ' (${equippedIndex == 0 ? "LEADER" : "#$equippedIndex 슬롯 장착 중"})' : ''}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: card.rarity == 'UR'
                                              ? Colors.amber.shade900
                                              : (card.rarity == 'SR' ? Colors.purple.shade800 : Colors.blueGrey.shade700),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'CP ${card.deckCost}',
                                          style: TextStyle(
                                            color: card.rarity == 'UR' ? Colors.amberAccent : Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (card.effect.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '효과: ${card.effect}',
                                        style: TextStyle(color: Colors.amber.shade100.withValues(alpha: 0.7), fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 장착 중인 경우: [해제] 버튼 제공
                                  if (isEquipped) ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: const Size(48, 32),
                                      ),
                                      onPressed: () {
                                        if (equippedIndex == 0 && currentDeck.length == 1) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('리더 카드는 최소 1장 유지되어야 합니다. 교체해 주세요.'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                          return;
                                        }
                                        setState(() {
                                          currentDeck.removeWhere((c) => c.id == card.id);
                                        });
                                        setModalState(() {});
                                      },
                                      child: const Text('해제', style: TextStyle(fontSize: 11)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],

                                  // 장착 / 교체 버튼
                                  Builder(
                                    builder: (ctx) {
                                      // 코스트 초과 여부 계산: 미장착 카드를 추가/교체 시 초과 여부
                                      bool wouldExceedCost = false;
                                      if (!isEquipped) {
                                        final currentCost = currentDeck.fold(0, (sum, c) => sum + c.deckCost);
                                        // 교체 시: 기존 슬롯 카드 코스트 제거 후 새 카드 코스트 추가
                                        final removedCost = slotIndex < currentDeck.length ? currentDeck[slotIndex].deckCost : 0;
                                        final newCost = currentCost - removedCost + card.deckCost;
                                        wouldExceedCost = newCost > CardModel.maxDeckCost;
                                      }
                                      return ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: wouldExceedCost
                                              ? Colors.grey.shade800
                                              : (isEquipped ? Colors.blueGrey : Colors.indigo),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(54, 32),
                                        ),
                                        onPressed: wouldExceedCost
                                            ? () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '편성 코스트 초과! 최대 ${CardModel.maxDeckCost} CP를 넘을 수 없습니다.\n(UR은 10 CP, SR은 3 CP, R은 2 CP, ☆2는 1 CP)',
                                                    ),
                                                    backgroundColor: Colors.red.shade800,
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            : () {
                                                setState(() {
                                                  if (isEquipped) {
                                                    // 이미 장착된 카드라면 위치 스왑
                                                    if (slotIndex < currentDeck.length) {
                                                      final temp = currentDeck[slotIndex];
                                                      currentDeck[slotIndex] = currentDeck[equippedIndex];
                                                      currentDeck[equippedIndex] = temp;
                                                    }
                                                  } else {
                                                    // 미장착 카드: 해당 슬롯 교체 또는 추가
                                                    if (slotIndex < currentDeck.length) {
                                                      currentDeck[slotIndex] = card;
                                                    } else if (currentDeck.length < 10) {
                                                      currentDeck.add(card);
                                                    }
                                                  }
                                                });
                                                Navigator.pop(context);
                                              },
                                        child: Text(
                                          wouldExceedCost
                                              ? 'CP초과'
                                              : (isEquipped
                                                  ? (isCurrentSlotCard ? '선택됨' : '스왑')
                                                  : (slotIndex < currentDeck.length ? '교체' : '장착')),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 4개 직업 덱이 모두 10장 완성되었는지 검증
  bool _isAllDecksReady() {
    return _equippedDecks.values.every(
      (deck) => deck.length == 10 && deck.fold(0, (sum, c) => sum + c.deckCost) <= CardModel.maxDeckCost,
    );
  }

  // 스탯 합산 연산 함수
  int _calculateStat(JobClass job, String statType) {
    final deck = _equippedDecks[job] ?? [];
    int total = 0;

    for (var card in deck) {
      if (statType == 'HP') {
        total += (card.value * 5);
      }
      if (statType == 'PHYSICAL' && job == JobClass.mercenary) {
        total += card.value;
      }
      if (statType == 'MAGIC' &&
          (job == JobClass.thief || job == JobClass.wealthy)) {
        total += card.value;
      }
      if (statType == 'HEAL' && job == JobClass.bard) {
        total += card.value;
      }
    }
    return total;
  }

  Color _getAttributeColor(CardAttribute attribute) {
    switch (attribute) {
      case CardAttribute.fire:
        return Colors.red.shade700;
      case CardAttribute.wind:
        return Colors.green.shade700;
      case CardAttribute.water:
        return Colors.blue.shade700;
    }
  }

  Color _getRarityChipColor(String rarity) {
    switch (rarity) {
      case 'UR':
        return Colors.amber.shade900;
      case 'SR':
        return Colors.purple.shade900;
      case 'R':
        return Colors.blue.shade900;
      case '☆2':
        return Colors.blueGrey.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipped = _equippedDecks[_currentJob]!;
    final leaderCard = equipped.isNotEmpty ? equipped[0] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24), // 가로형 게임 전용 어두운 배경색
      appBar: AppBar(
        title: Text(
          widget.isFromLobby ? '덱 편집' : '덱 편성',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111116),
        foregroundColor: Colors.white,
        elevation: 0,
        // 뒤로가기 시 편성 덱 상태를 로비로 반환
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _equippedDecks),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '편성할 아서와 교체할 기사 카드를 선택해 주세요',
                style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 직업 선택 탭
            Container(
              color: const Color(0xFF111116),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: JobClass.values.map((job) {
                  final isSelected = _currentJob == job;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? job.color
                              : Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => setState(() => _currentJob = job),
                        child: Text(
                          '${job.label} 덱',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // 메인 3컬럼 레이아웃 (좌: 캐릭터/스탯 | 중앙: 리더+3x3 덱 | 우: 액션 버튼)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [LEFT COLUMN] 캐릭터 카드 및 파티 스탯 패널
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A32),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade700),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 캐릭터 아이콘 / Rank
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shield,
                                      color: _currentJob.color,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _currentJob.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade800,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'RANK SS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // 스탯 정보 패널 (원작 UI 스타일)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  _buildStatRow(
                                    'HP',
                                    _calculateStat(
                                      _currentJob,
                                      'HP',
                                    ).toString(),
                                    Colors.greenAccent,
                                  ),
                                  const Divider(
                                    color: Colors.white24,
                                    height: 8,
                                  ),
                                  _buildStatRow(
                                    '물리대미지',
                                    _calculateStat(
                                      _currentJob,
                                      'PHYSICAL',
                                    ).toString(),
                                    Colors.orangeAccent,
                                  ),
                                  const Divider(
                                    color: Colors.white24,
                                    height: 8,
                                  ),
                                  _buildStatRow(
                                    '마법대미지',
                                    _calculateStat(
                                      _currentJob,
                                      'MAGIC',
                                    ).toString(),
                                    Colors.purpleAccent,
                                  ),
                                  const Divider(
                                    color: Colors.white24,
                                    height: 8,
                                  ),
                                  _buildStatRow(
                                    '회복량',
                                    _calculateStat(
                                      _currentJob,
                                      'HEAL',
                                    ).toString(),
                                    Colors.lightBlueAccent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // [CENTER COLUMN] 1 LEADER + 3x3 GRID 카드 편성 영역
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // 1. LEADER 슬롯 (상단 배너 카드)
                          GestureDetector(
                            onTap: () => _showCardSwapModal(0),
                            child: Container(
                              width: double.infinity,
                              height: 64,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A3A46),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                              child: leaderCard == null
                                  ? const Center(
                                      child: Text(
                                        'LEADER 카드 선택',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'LEADER',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: _getAttributeColor(
                                            leaderCard.attribute,
                                          ),
                                          child: Text(
                                            '${leaderCard.cost}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                leaderCard.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '파라미터 x 1.5배 보너스',
                                                style: TextStyle(
                                                  color: Colors.amber.shade200,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.autorenew,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 2. 3x3 카드 그리드 (9장)
                          Expanded(
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                    childAspectRatio: 1.1,
                                  ),
                              itemCount: 9,
                              itemBuilder: (context, index) {
                                final cardIndex = index + 1; // 0번은 Leader
                                final card = cardIndex < equipped.length
                                    ? equipped[cardIndex]
                                    : null;

                                return GestureDetector(
                                  onTap: () => _showCardSwapModal(cardIndex),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: card != null
                                          ? const Color(0xFF2A2A32)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: card != null
                                            ? _getAttributeColor(card.attribute)
                                            : Colors.white24,
                                        width: card != null ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: card == null
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  color: Colors.white38,
                                                  size: 22,
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  '카드 추가',
                                                  style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Stack(
                                            children: [
                                              // AP 코스트 배지 (좌상단)
                                              Positioned(
                                                top: 4,
                                                left: 4,
                                                child: CircleAvatar(
                                                  radius: 11,
                                                  backgroundColor:
                                                      _getAttributeColor(
                                                        card.attribute,
                                                      ),
                                                  child: Text(
                                                    '${card.cost}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 우상단: [X] 제거(해제) 버튼
                                              Positioned(
                                                top: 2,
                                                right: 2,
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: () {
                                                    setState(() {
                                                      equipped.removeAt(
                                                        cardIndex,
                                                      );
                                                    });
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          2,
                                                        ),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              Colors.redAccent,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 카드 이름 & 수치 (중앙)
                                              Center(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4.0,
                                                      ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (card.rarity.isNotEmpty)
                                                            Container(
                                                              margin: const EdgeInsets.only(bottom: 2, right: 2),
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                                              decoration: BoxDecoration(
                                                                color: card.rarity == 'UR'
                                                                    ? Colors.amber.shade900
                                                                    : (card.rarity == 'SR' ? Colors.purple.shade900 : Colors.blueGrey.shade800),
                                                                borderRadius: BorderRadius.circular(3),
                                                              ),
                                                              child: Text(
                                                                card.rarity,
                                                                style: TextStyle(
                                                                  color: card.rarity == 'UR' ? Colors.amberAccent : Colors.white,
                                                                  fontSize: 8,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          if (card.isCommon)
                                                            Container(
                                                              margin: const EdgeInsets.only(bottom: 2),
                                                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                                                              decoration: BoxDecoration(
                                                                color: Colors.teal.shade800,
                                                                borderRadius: BorderRadius.circular(3),
                                                              ),
                                                              child: const Text(
                                                                '공용',
                                                                style: TextStyle(
                                                                  color: Colors.tealAccent,
                                                                  fontSize: 8,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      Text(
                                                        card.name,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${card.value}',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .amber
                                                              .shade200,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (card.drawBonus > 0)
                                                        Text(
                                                          '+${card.drawBonus} 드로우',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .cyanAccent,
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
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // [RIGHT COLUMN] 서브 액션 버튼 패널
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // 덱 편성 장수 현황
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (equipped.length == 10 && !_isDeckCostOver(_currentJob))
                                    ? Colors.greenAccent.withValues(alpha: 0.5)
                                    : Colors.amber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Builder(
                              builder: (ctx) {
                                final currentCp = _currentDeckCost(_currentJob);
                                final maxCp = CardModel.maxDeckCost;
                                final cpRatio = (currentCp / maxCp).clamp(0.0, 1.0);
                                final isOver = currentCp > maxCp;
                                return Column(
                                  children: [
                                    const Text(
                                      '덱 편성 현황',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${equipped.length} / 10장',
                                      style: TextStyle(
                                        color: (equipped.length == 10 && !isOver)
                                            ? Colors.greenAccent
                                            : Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      equipped.length == 10 && !isOver
                                          ? '편성 완료'
                                          : (isOver ? '코스트 초과!' : '카드 필요'),
                                      style: TextStyle(
                                        color: isOver
                                            ? Colors.redAccent
                                            : (equipped.length == 10
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Divider(color: Colors.white12, height: 1),
                                    const SizedBox(height: 6),
                                    // CP 게이지 바
                                    Row(
                                      children: [
                                        Text(
                                          'CP',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: LinearProgressIndicator(
                                              value: cpRatio,
                                              backgroundColor: Colors.white12,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                isOver
                                                    ? Colors.redAccent
                                                    : (cpRatio > 0.8
                                                        ? Colors.amber
                                                        : Colors.indigoAccent),
                                              ),
                                              minHeight: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$currentCp / $maxCp',
                                          style: TextStyle(
                                            color: isOver ? Colors.redAccent : Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => _autoFillDeck(_currentJob),
                            child: const Text(
                              '추천 덱',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.isFromLobby)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Colors.blueAccent.shade200,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context, _equippedDecks);
                              },
                              icon: const Icon(Icons.arrow_back, size: 20),
                              label: const Text(
                                '돌아가기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAllDecksReady()
                                    ? Colors.redAccent.shade700
                                    : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isAllDecksReady()
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BattleScreen(
                                            equippedDecks: _equippedDecks,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: const Text(
                                '레이드 시작',
                                style: TextStyle(
                                  fontSize: 14,
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
