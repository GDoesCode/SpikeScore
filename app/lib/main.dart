import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'edition.dart';
import 'match_engine.dart';
import 'screens/home_screen.dart';

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
      title: Edition.appName(Edition.lite),
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}