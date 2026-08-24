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

  @override
  Widget build(BuildContext context) {
    final bottomBarHeight = _shell.usesNativeNavigation ? 0.0 : 102.0;
    return Material(
      color: NeoColors.canvas(context),
      child: Stack(
        children: [
          Positioned.fill(child: _page(bottomBarHeight)),
          if (!_shell.usesNativeNavigation)
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: SafeArea(
                top: false,
                child: NeoBottomNavigation(
                  selection: _selectedTab,
                  workoutsLabel: _shell.workoutsLabel,
                  updateAvailable: _shell.updateAvailable,
                  onSelect: _select,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _page(double bottomBarHeight) {
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

class NeoBottomNavigation extends StatelessWidget {
  const NeoBottomNavigation({
    required this.selection,
    required this.workoutsLabel,
    required this.updateAvailable,
    required this.onSelect,
    super.key,
  });

  final FudAppTab selection;
  final String workoutsLabel;
  final bool updateAvailable;
  final ValueChanged<FudAppTab> onSelect;

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
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: NeoColors.cobalt,
        border: Border.all(color: NeoColors.ink(context), width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: tabs.map((item) {
          final selected = item.$1 == selection;
          final badge = updateAvailable && item.$1 == FudAppTab.settings;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: item.$2,
              child: Material(
                color: selected ? NeoColors.acid : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => onSelect(item.$1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.$3,
                              color: selected ? Colors.black : Colors.white,
                              size: 25,
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.$2,
                                maxLines: 1,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (badge)
                        Positioned(
                          right: 7,
                          top: 3,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
