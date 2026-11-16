import 'package:flutter/material.dart';
import 'raid_deck_screen.dart';
import '../models/card_model.dart';

class BossSelectionScreen extends StatelessWidget {
  const BossSelectionScreen({super.key});

  // 간단히 3개의 더미 보스 리스트
  static const List<String> _bosses = [
    '불의 군주 플레임하트',
    '바람의 여왕 스톰퀸',
    '대지의 거인 루드워드',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보스 선택'),
        backgroundColor: const Color(0xFF111116),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _bosses.length,
        itemBuilder: (context, index) {
          final boss = _bosses[index];
          return ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(boss),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 선택한 보스와 함께 레이드 덱 화면으로 이동 (현재는 빈 덱 전달)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => RaidDeckScreen(
                    initialDecks: <JobClass, List<CardModel>>{},
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
