import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_test/models/card_model.dart';
import 'package:test_test/screens/battle_screen.dart';
import 'package:test_test/screens/result_screen.dart';

void main() {
  late Map<JobClass, List<CardModel>> testDecks;

  setUp(() {
    testDecks = {};
    for (final job in JobClass.values) {
      testDecks[job] = CardModel.getCardPoolByJob(job).take(10).toList();
    }
  });

  testWidgets('ResultScreen 승리(VICTORY) 화면 렌더링 및 5턴 이하 S RANK 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          isVictory: true,
          totalTurns: 4,
          destroyedParts: 2,
          maxChain: 4,
          equippedDecks: testDecks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 상단 승리 배너 및 S RANK 배지 검증
    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.text('S RANK'), findsOneWidget);
    expect(find.text('최단 턴 공략 성공!'), findsOneWidget);

    // 2. 중앙 좌측 전투 리포트 패널 검증
    expect(find.text('전투 분석 리포트'), findsOneWidget);
    expect(find.text('TOTAL TURNS'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2 / 2 파괴'), findsOneWidget);
    expect(find.text('무기/방패 완전 파괴'), findsOneWidget);
    expect(find.text('4 Chain'), findsOneWidget);
    expect(find.text('체인 위력 x2.0 배율'), findsOneWidget);

    // 3. 중앙 우측 파티 MVP 요약 패널 검증
    expect(find.text('출전 파티 및 리더 카드 요약'), findsOneWidget);
    expect(find.text('용병'), findsOneWidget);
    expect(find.text('부호'), findsOneWidget);
    expect(find.text('도적'), findsOneWidget);
    expect(find.text('가희'), findsOneWidget);
    expect(find.text('LEADER'), findsNWidgets(4)); // 4개 직업 리더 카드

    // 4. 하단 액션 버튼 검증
    expect(find.text('다시 도전'), findsOneWidget);
    expect(find.text('덱 편성(메인)으로'), findsOneWidget);
  });

  testWidgets('ResultScreen 패배(DEFEAT) 화면 렌더링 및 FAIL 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          isVictory: false,
          totalTurns: 6,
          destroyedParts: 1,
          maxChain: 2,
          equippedDecks: testDecks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 패배 배너 및 FAIL 등급 검증
    expect(find.text('DEFEAT'), findsOneWidget);
    expect(find.text('FAIL'), findsOneWidget);
    expect(find.text('보스 공략 실패 - 파티 전멸'), findsOneWidget);
    expect(find.text('1 / 2 파괴'), findsOneWidget);
    expect(find.text('2 Chain'), findsOneWidget);
  });

  testWidgets('다시 도전 버튼 탭 시 BattleScreen으로 재진입 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          isVictory: true,
          totalTurns: 5,
          destroyedParts: 2,
          maxChain: 3,
          equippedDecks: testDecks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 다시 도전 버튼 탭
    await tester.tap(find.text('다시 도전'));
    await tester.pumpAndSettle();

    // BattleScreen으로 이동하여 TURN 1이 표시되는지 검증
    expect(find.byType(BattleScreen), findsOneWidget);
    expect(find.text('TURN 1'), findsOneWidget);
  });
}
