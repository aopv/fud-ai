import 'dart:async';

import 'package:flutter/material.dart';

import '../coach/coach_screen.dart';
import '../home/home_screen.dart';
import '../native/app_channel.dart';
import '../native/progress_channel.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import '../workouts/workouts_screen.dart';
import 'neo_components.dart';

class SharedAppShell extends StatefulWidget {
  const SharedAppShell({
    required this.repository,
    required this.initialSnapshot,
    required this.progressRepository,
    super.key,
  });

  final AppRepository repository;
  final AppShellSnapshot initialSnapshot;
  final ProgressRepository progressRepository;

  @override
  State<SharedAppShell> createState() => _SharedAppShellState();
}

class _SharedAppShellState extends State<SharedAppShell> {
  late AppShellSnapshot _shell = widget.initialSnapshot;
  late FudAppTab _selectedTab = _shell.selectedTab;
  final Map<FudAppTab, Map<Object?, Object?>> _pages = {};
  final Set<FudAppTab> _loading = {};
  final Map<FudAppTab, Object> _errors = {};
  StreamSubscription<String?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.changes.listen(_handleChange);
    _load(_selectedTab);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleChange(String? tabName) async {
    if (tabName == null || tabName == 'shell') {
      try {
        final shell = await widget.repository.loadShell();
        if (mounted) setState(() => _shell = shell);
      } catch (_) {
        // A transient native refresh cannot invalidate already rendered data.
      }
    }
    if (tabName == null) {
      await _load(_selectedTab, force: true);
      return;
    }
    for (final tab in FudAppTab.values) {
      if (tab.name == tabName) await _load(tab, force: true);
    }
  }

  Future<void> _load(FudAppTab tab, {bool force = false}) async {
    if (tab == FudAppTab.progress) return;
    if (!force && (_pages.containsKey(tab) || _loading.contains(tab))) return;
    setState(() {
      _loading.add(tab);
      _errors.remove(tab);
    });
    try {
      final page = await widget.repository.loadPage(tab);
      if (!mounted) return;
      setState(() {
        _pages[tab] = page;
        _loading.remove(tab);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading.remove(tab);
        _errors[tab] = error;
      });
    }
  }

  Future<Object?> _perform(
    String action, {
    Map<String, Object?> arguments = const {},
  }) async {
    final result = await widget.repository.perform(
      action,
      arguments: arguments,
    );
    await _load(_selectedTab, force: true);
    return result;
  }

  Future<void> _select(FudAppTab tab) async {
    if (tab == _selectedTab) return;
    setState(() => _selectedTab = tab);
    await widget.repository.selectTab(tab);
    await _load(tab);
  }

  Future<void> _quickAdd() async {
    if (_selectedTab != FudAppTab.home) {
      setState(() => _selectedTab = FudAppTab.home);
      await widget.repository.selectTab(FudAppTab.home);
    }
    await widget.repository.perform(
      'home.quickAction',
      arguments: const {'quickAction': 'CAMERA'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NeoColors.canvas(context),
      child: Row(
        children: [
          Expanded(child: _page()),
          if (!_shell.usesNativeNavigation)
            SafeArea(
              left: false,
              child: NeoRightNavigation(
                selection: _selectedTab,
                workoutsLabel: _shell.workoutsLabel,
                updateAvailable: _shell.updateAvailable,
                onSelect: _select,
                onQuickAdd: _quickAdd,
              ),
            ),
        ],
      ),
    );
  }

  Widget _page() {
    if (_selectedTab == FudAppTab.progress) {
      return ProgressScreen(repository: widget.progressRepository);
    }
    final snapshot = _pages[_selectedTab];
    if (snapshot == null) {
      if (_errors.containsKey(_selectedTab)) {
        return ColoredBox(
          color: NeoColors.canvas(context),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: NeoFrame(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: NeoColors.cobalt,
                      size: 38,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'THIS PAGE COULD NOT LOAD',
                      style: TextStyle(
                        color: NeoColors.ink(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NeoButton(
                      label: 'Try Again',
                      onPressed: () => _load(_selectedTab, force: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return const NeoLoading();
    }
    return switch (_selectedTab) {
      FudAppTab.home => SharedHomeScreen(snapshot: snapshot, perform: _perform),
      FudAppTab.coach => SharedCoachScreen(
        snapshot: snapshot,
        perform: _perform,
      ),
      FudAppTab.settings => SharedSettingsScreen(
        snapshot: snapshot,
        perform: _perform,
      ),
      FudAppTab.workouts => SharedWorkoutsScreen(
        snapshot: snapshot,
        perform: _perform,
      ),
      FudAppTab.progress => ProgressScreen(
        repository: widget.progressRepository,
      ),
    };
  }
}

class NeoRightNavigation extends StatelessWidget {
  const NeoRightNavigation({
    required this.selection,
    required this.workoutsLabel,
    required this.updateAvailable,
    required this.onSelect,
    required this.onQuickAdd,
    super.key,
  });

  final FudAppTab selection;
  final String workoutsLabel;
  final bool updateAvailable;
  final ValueChanged<FudAppTab> onSelect;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (FudAppTab.home, 'HOME', Icons.home),
      (FudAppTab.progress, 'PROGRESS', Icons.bar_chart),
      (FudAppTab.coach, 'AI COACH', Icons.auto_awesome),
      (FudAppTab.settings, 'SETTINGS', Icons.settings),
      (FudAppTab.workouts, workoutsLabel.toUpperCase(), Icons.fitness_center),
    ];
    return Container(
      key: const ValueKey('navigation.rail'),
      width: 82,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(left: BorderSide(color: Colors.white70, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            width: double.infinity,
            color: NeoColors.cobalt,
            alignment: Alignment.center,
            child: const Text(
              'FÜD\nAI',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 0.9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...tabs.map((item) {
            final selected = item.$1 == selection;
            final badge = updateAvailable && item.$1 == FudAppTab.settings;
            return SizedBox(
              height: 72,
              child: Semantics(
                selected: selected,
                button: true,
                label: item.$2,
                child: InkWell(
                  key: ValueKey('navigation.${item.$1.name}'),
                  onTap: () => onSelect(item.$1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? NeoColors.cobalt.withValues(alpha: 0.18)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: selected
                              ? NeoColors.cobalt
                              : Colors.transparent,
                          width: 4,
                        ),
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.$3,
                                color: selected
                                    ? NeoColors.cobalt
                                    : Colors.white,
                                size: 25,
                              ),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item.$2,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: selected
                                        ? NeoColors.cobalt
                                        : Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (badge)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 14,
                              height: 14,
                              alignment: Alignment.center,
                              color: NeoColors.acid,
                              child: const Text(
                                '!',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TRACK.\nLEARN.\nWIN.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Camera and note',
            child: InkWell(
              key: const ValueKey('navigation.quickAdd'),
              onTap: onQuickAdd,
              child: Container(
                margin: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                height: 60,
                decoration: BoxDecoration(
                  color: NeoColors.acid,
                  border: Border.all(color: NeoColors.cobalt, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: Colors.black, size: 29),
                    Text(
                      'ADD',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
