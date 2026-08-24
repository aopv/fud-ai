import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fud_ai_shared/src/app/app_shell.dart';
import 'package:fud_ai_shared/src/native/app_channel.dart';
import 'package:fud_ai_shared/src/native/progress_channel.dart';
import 'package:fud_ai_shared/src/progress/progress_models.dart';

class _FakeAppRepository implements AppRepository {
  final _changes = StreamController<String?>.broadcast();
  FudAppTab? selectedTab;
  String? action;
  Map<String, Object?>? arguments;

  @override
  Stream<String?> get changes => _changes.stream;

  @override
  Future<AppShellSnapshot> loadShell() async => _shell;

  @override
  Future<Map<Object?, Object?>> loadPage(FudAppTab tab) async => switch (tab) {
    FudAppTab.home => <Object?, Object?>{
      'title': 'Today',
      'dateLabel': 'Monday, August 24',
      'calorieGoal': 2000,
      'weekDays': <Object?>[],
      'mealGroups': <Object?>[],
    },
    FudAppTab.coach => <Object?, Object?>{
      'messages': <Object?>[],
      'suggestions': <Object?>[],
    },
    FudAppTab.settings => <Object?, Object?>{'sections': <Object?>[]},
    FudAppTab.workouts => <Object?, Object?>{
      'mode': 'log',
      'exercises': <Object?>[],
    },
    FudAppTab.progress => <Object?, Object?>{},
  };

  @override
  Future<Object?> perform(
    String nextAction, {
    Map<String, Object?> arguments = const {},
  }) async {
    action = nextAction;
    this.arguments = arguments;
    return null;
  }

  @override
  Future<void> selectTab(FudAppTab tab) async => selectedTab = tab;

  Future<void> dispose() => _changes.close();
}

class _UnusedProgressRepository implements ProgressRepository {
  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<ProgressSnapshot> load(ProgressRange range) =>
      throw StateError('Progress should not load in this test.');

  @override
  Future<void> perform(String action) async {}
}

const _shell = AppShellSnapshot(
  platform: 'android',
  isDark: false,
  usesNativeNavigation: false,
  selectedTab: FudAppTab.home,
  bottomContentInset: 0,
  workoutsLabel: 'WORKOUTS',
  updateAvailable: false,
);

void main() {
  testWidgets('renders navigation on the right and preserves quick add', (
    tester,
  ) async {
    final repository = _FakeAppRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SharedAppShell(
          repository: repository,
          initialSnapshot: _shell,
          progressRepository: _UnusedProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = find.byKey(const ValueKey('navigation.rail'));
    expect(rail, findsOneWidget);
    expect(find.byType(NeoRightNavigation), findsOneWidget);
    expect(tester.getTopLeft(rail).dx, greaterThan(700));

    await tester.tap(find.byKey(const ValueKey('navigation.settings')));
    await tester.pumpAndSettle();
    expect(repository.selectedTab, FudAppTab.settings);

    await tester.tap(find.byKey(const ValueKey('navigation.quickAdd')));
    await tester.pumpAndSettle();
    expect(repository.selectedTab, FudAppTab.home);
    expect(repository.action, 'home.quickAction');
    expect(repository.arguments, {'quickAction': 'CAMERA'});

    await repository.dispose();
  });
}
