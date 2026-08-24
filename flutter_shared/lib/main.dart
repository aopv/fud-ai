import 'package:flutter/material.dart';

import 'src/app/app_shell.dart';
import 'src/app/neo_components.dart';
import 'src/native/app_channel.dart';
import 'src/native/progress_channel.dart';
import 'src/progress/progress_screen.dart';
import 'src/theme/neo_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FudAiSharedApp());
}

class FudAiSharedApp extends StatelessWidget {
  const FudAiSharedApp({
    super.key,
    this.progressRepository,
    this.appRepository,
  });

  final ProgressRepository? progressRepository;
  final AppRepository? appRepository;

  @override
  Widget build(BuildContext context) {
    final nativeProgress =
        progressRepository ?? const NativeProgressRepository();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fud AI',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NeoPalette.cobaltLight,
          brightness: Brightness.light,
          surface: NeoPalette.surfaceLight,
        ),
        scaffoldBackgroundColor: NeoPalette.canvasLight,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NeoPalette.cobaltDark,
          brightness: Brightness.dark,
          surface: NeoPalette.surfaceDark,
        ),
        scaffoldBackgroundColor: NeoPalette.canvasDark,
        useMaterial3: true,
      ),
      home: _SharedBootstrap(
        appRepository: appRepository,
        progressRepository: nativeProgress,
      ),
    );
  }
}

class _SharedBootstrap extends StatelessWidget {
  const _SharedBootstrap({
    required this.appRepository,
    required this.progressRepository,
  });

  final AppRepository? appRepository;
  final ProgressRepository progressRepository;

  @override
  Widget build(BuildContext context) {
    // Existing iOS/Android hosts that only expose the Progress bridge must keep
    // working throughout the shell migration. Test injection of only a Progress
    // repository also intentionally uses this compatibility path.
    if (appRepository == null &&
        progressRepository is! NativeProgressRepository) {
      return ProgressScreen(repository: progressRepository);
    }
    final repository = appRepository ?? NativeAppRepository();
    return FutureBuilder<AppShellSnapshot>(
      future: repository.loadShell(),
      builder: (context, state) {
        if (state.hasData) {
          return SharedAppShell(
            repository: repository,
            initialSnapshot: state.data!,
            progressRepository: progressRepository,
          );
        }
        if (state.hasError) {
          return ProgressScreen(repository: progressRepository);
        }
        return const NeoLoading();
      },
    );
  }
}
