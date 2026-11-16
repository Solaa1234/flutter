import 'package:flutter/material.dart';

import 'screens/lobby_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '괴리성 밀리언 아서 오마주',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Container(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9, // 안드로이드 가로 화면비(16:9) 고정
              child: FittedBox(
                fit: BoxFit.contain, // 화면 크기를 키우거나 줄여도 모든 UI와 아이콘이 자동 비례 확대/축소
                child: SizedBox(
                  width: 1280,
                  height: 720,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: const Size(1280, 720),
                    ),
                    child: child ?? const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      home: const LobbyScreen(),
    );
  }
}
