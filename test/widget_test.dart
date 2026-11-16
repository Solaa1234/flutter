import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_test/main.dart';

void main() {
  testWidgets('로비 화면 정상 렌더링 스모크 테스트', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('괴리성 밀리언 아서'), findsOneWidget);
    expect(find.text('퀘스트'), findsOneWidget);
    expect(find.text('아레나'), findsOneWidget);
    expect(find.text('거점'), findsOneWidget);
  });
}
