import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_test/models/card_model.dart';
import 'package:test_test/screens/battle_screen.dart';

void main() {
  late Map<JobClass, List<CardModel>> testDecks;

  setUp(() {
    testDecks = {};
    for (final job in JobClass.values) {
      testDecks[job] = CardModel.getCardPoolByJob(job).take(10).toList();
    }
  });

  testWidgets('BattleScreen 가로형 UI 정상 렌더링 및 주요 컴포넌트 표시 검증', (tester) async {
    // 가로 모드 해상도 세팅 (1280 x 720)
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(equippedDecks: testDecks),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 상단 바 검증
    expect(find.text('TURN 1'), findsOneWidget);
    expect(find.textContaining('광폭화 0스택'), findsOneWidget);
    expect(find.text('AI 자동 모드'), findsOneWidget);

    // 2. 보스 영역 (3개 부위 및 상성 관계도) 검증
    expect(find.text('빙결룡 키메라'), findsOneWidget);
    expect(find.textContaining('상성: 🔥불 > 🌪바람 > 💧물 > 🔥불'), findsOneWidget);
    expect(find.text('화염 날개 [무기]'), findsOneWidget);
    expect(find.text('본체 [빙결룡]'), findsOneWidget);
    expect(find.text('질풍 갑각 [방패]'), findsOneWidget);
    expect(find.textContaining('약점:'), findsWidgets); // 보스 부위별 약점 배지

    // 3. 파티원 4인 상태 바 검증
    expect(find.text('용병'), findsAtLeastNWidgets(1));
    expect(find.text('부호'), findsAtLeastNWidgets(1));
    expect(find.text('도적'), findsAtLeastNWidgets(1));
    expect(find.text('가희'), findsAtLeastNWidgets(1));

    // 4. 하단 핸드 & 액션 영역 검증
    expect(find.text('용병 AP'), findsOneWidget);
    expect(find.text('AP 3 / 3'), findsOneWidget);
    expect(find.textContaining('다음 드로우 +'), findsOneWidget);
    expect(find.text('턴 종료 (정산)'), findsOneWidget);

    // 5. 손패 카드별 코스트(AP소모량) 및 상성 표기 검증
    expect(find.textContaining(' AP'), findsWidgets); // 카드별 코스트(AP소모량)
    expect(find.textContaining('속성'), findsWidgets); // 속성 명칭 배지
  });

  testWidgets('카드 탭 시 선택/해제 및 AP 변화 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(equippedDecks: testDecks),
      ),
    );
    await tester.pumpAndSettle();

    // 1턴 AP(3) 내에서 선택 가능한 카드 슬롯 터치
    final cards = find.byType(AnimatedContainer);
    expect(cards, findsWidgets);

    // 3코스트 이하의 선택 가능한 카드를 찾아서 탭
    bool tapped = false;
    for (int i = 0; i < cards.evaluate().length; i++) {
      await tester.tap(cards.at(i));
      await tester.pumpAndSettle();
      if (find.text('READY').evaluate().isNotEmpty) {
        tapped = true;
        break;
      }
    }

    // 최소 한 장 이상 정상 선택(READY 배지 표시)됨을 검증
    expect(tapped, isTrue);
    expect(find.text('READY'), findsWidgets);
  });

  testWidgets('턴 종료 (정산) 버튼 클릭 시 정산 다이얼로그 표시 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(equippedDecks: testDecks),
      ),
    );
    await tester.pumpAndSettle();

    // 턴 종료 버튼 탭
    await tester.tap(find.text('턴 종료 (정산)'));
    await tester.pumpAndSettle();

    // 정산 다이얼로그 확인
    expect(find.text('제 1 턴 정산 결과'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);

    // 확인 클릭
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 2턴으로 진행 확인
    expect(find.text('TURN 2'), findsOneWidget);
  });

  testWidgets('손패 카드 길게 누를 경우 세부 효과 모달 다이얼로그 노출 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(equippedDecks: testDecks),
      ),
    );
    await tester.pumpAndSettle();

    // 손패 카드 속성 배지 길게 누름
    final cardSlot = find.textContaining('속성').first;
    await tester.longPress(cardSlot);
    await tester.pumpAndSettle();

    // 카드 세부 효과 다이얼로그가 열렸는지 검증
    expect(find.textContaining('속성 |'), findsOneWidget);
    expect(find.textContaining('현재 타겟:'), findsOneWidget);
    expect(find.textContaining('속성 상성:'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);

    // 닫기 클릭 시 정상 종료 검증
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsNothing);
  });
}
