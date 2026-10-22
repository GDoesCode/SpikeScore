import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'match_engine.dart';
import 'screens/match_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MatchEngine(),
      child: const SpikeScoreApp(),
    ),
  );
}

class SpikeScoreApp extends StatelessWidget {
  const SpikeScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpikeScore',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MatchScreen(),
    );
  }
}