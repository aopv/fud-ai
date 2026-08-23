import 'package:flutter/cupertino.dart';

import 'src/native/progress_channel.dart';
import 'src/progress/progress_screen.dart';
import 'src/theme/neo_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FudAiSharedApp());
}

class FudAiSharedApp extends StatelessWidget {
  const FudAiSharedApp({super.key, this.progressRepository});

  final ProgressRepository? progressRepository;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Fud AI',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: NeoPalette.cobaltLight,
        scaffoldBackgroundColor: NeoPalette.canvasLight,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: NeoPalette.inkLight,
          ),
        ),
      ),
      home: ProgressScreen(
        repository: progressRepository ?? const NativeProgressRepository(),
      ),
    );
  }
}
