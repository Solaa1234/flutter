import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_test/screens/raid_deck_screen.dart';

void main() {
  testWidgets('덱 카드 우상단 X 버튼 터치 시 덱에서 카드 제거 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RaidDeckScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 초기 상태: 10장 편성 완료 상태
    expect(find.text('10 / 10장'), findsOneWidget);

    // 3x3 그리드 카드의 우상단 'X' 제거 버튼을 찾아 탭
    final closeButtons = find.byIcon(Icons.close);
    expect(closeButtons, findsWidgets);

    // 첫 번째 서브 카드 제거
    await tester.tap(closeButtons.first);
    await tester.pumpAndSettle();

    // 9장으로 감소하고 빈 슬롯('카드 추가')이 나타났는지 검증
    expect(find.text('9 / 10장'), findsOneWidget);
    expect(find.text('카드 추가'), findsOneWidget);
  });

  testWidgets('카드 추가 슬롯 탭 시 교체 모달 열림 및 속성 필터/장착/해제 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RaidDeckScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 먼저 1장을 제거하여 빈 슬롯을 만듦
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // 빈 슬롯('카드 추가') 탭하여 모달 열기
    await tester.tap(find.text('카드 추가'));
    await tester.pumpAndSettle();

    // 모달창 상단 헤더 및 속성/등급 필터 확인
    expect(find.textContaining('덱 카드'), findsOneWidget);
    expect(find.text('속성 필터: '), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('불'), findsOneWidget);
    expect(find.text('바람'), findsOneWidget);
    expect(find.text('물'), findsOneWidget);
    expect(find.text('등급 필터: '), findsOneWidget);
    expect(find.text('전체 등급'), findsOneWidget);
    expect(find.text('UR'), findsWidgets);
    expect(find.text('SR'), findsWidgets);

    // 스크롤바 위젯 존재 검증
    expect(find.byType(Scrollbar), findsOneWidget);

    // 모달 내 '해제' 버튼 및 '장착' 버튼 존재 검증
    expect(find.text('해제'), findsWidgets);
    expect(find.text('장착'), findsWidgets);

    // 등급 필터 'UR' 탭 동작 검증
    await tester.tap(find.text('UR').first);
    await tester.pumpAndSettle();

    // 다시 '전체 등급' 탭하여 복원 검증
    await tester.tap(find.text('전체 등급'));
    await tester.pumpAndSettle();
    expect(find.text('해제'), findsWidgets);

    // 닫기 버튼 탭
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text('속성 필터: '), findsNothing);
  });

  testWidgets('로비에서 진입 시 레이드 시작 대신 돌아가기 버튼 표시 검증', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RaidDeckScreen(isFromLobby: true),
      ),
    );
    await tester.pumpAndSettle();

    // 레이드 시작 버튼은 없어야 함
    expect(find.text('레이드 시작'), findsNothing);

    // 돌아가기 버튼이 존재해야 함
    expect(find.text('돌아가기'), findsOneWidget);
    expect(find.text('덱 편집'), findsOneWidget);
  });
}
