import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../native/progress_channel.dart';
import '../theme/neo_theme.dart';
import 'progress_models.dart';

enum _BodyMetric { weight, bodyFat }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.repository});

  final ProgressRepository repository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;
  _BodyMetric _metric = _BodyMetric.weight;
  ProgressSnapshot? _snapshot;
  Object? _error;
  int _requestEpoch = 0;
  StreamSubscription<void>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    _listenForNativeChanges();
    _load(_range);
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _changeSubscription?.cancel();
      _listenForNativeChanges();
      _load(_range);
    }
  }

  void _listenForNativeChanges() {
    _changeSubscription = widget.repository.changes.listen((_) {
      if (mounted) _load(_range);
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load(ProgressRange range) async {
    final epoch = ++_requestEpoch;
    setState(() {
      _range = range;
      _error = null;
    });
    try {
      final next = await widget.repository.load(range);
      if (!mounted || epoch != _requestEpoch) return;
      setState(() => _snapshot = next);
    } catch (error) {
      if (!mounted || epoch != _requestEpoch) return;
      setState(() => _error = error);
    }
  }

  Future<void> _action(String action) async {
    await widget.repository.perform(action);
    if (!mounted) return;
    await _load(_range);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = snapshot?.isDark == null
        ? platformBrightness
        : snapshot!.isDark!
        ? Brightness.dark
        : Brightness.light;
    final colors = NeoColors.forBrightness(brightness);
    if (defaultTargetPlatform == TargetPlatform.android) {
      final iconBrightness = brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: iconBrightness,
          systemNavigationBarIconBrightness: iconBrightness,
        ),
      );
    }

    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        top: snapshot?.safeAreaTop ?? true,
        bottom: false,
        child: snapshot == null
            ? _LoadingState(
                colors: colors,
                error: _error,
                retry: () => _load(_range),
              )
            : CustomScrollView(
                key: const ValueKey('progress.scroll'),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: () => _load(_range)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      NeoMetrics.screenInset,
                      16,
                      NeoMetrics.screenInset,
                      24 + snapshot.bottomContentInset,
                    ),
                    sliver: SliverList.list(
                      children: [
                        _Header(colors: colors, strings: snapshot.strings),
                        const SizedBox(height: NeoMetrics.sectionSpacing),
                        _RangePicker(
                          colors: colors,
                          selected: _range,
                          onChanged: _load,
                        ),
                        const SizedBox(height: NeoMetrics.sectionSpacing),
                        if (snapshot.showsBodyFat) ...[
                          _MetricPicker(
                            colors: colors,
                            strings: snapshot.strings,
                            selected: _metric,
                            onChanged: (value) =>
                                setState(() => _metric = value),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _metric == _BodyMetric.weight || !snapshot.showsBodyFat
                            ? _WeightPanel(
                                colors: colors,
                                snapshot: snapshot,
                                onLog: () => _action('logWeight'),
                              )
                            : _BodyFatPanel(
                                colors: colors,
                                snapshot: snapshot,
                                onLog: () => _action('logBodyFat'),
                              ),
                        if (snapshot.weightHistoryCount > 0) ...[
                          const SizedBox(height: NeoMetrics.sectionSpacing),
                          _HistoryLink(
                            colors: colors,
                            title: snapshot.strings['weightHistory'],
                            count: snapshot.weightHistoryCount,
                            strings: snapshot.strings,
                            acidIcon: false,
                            onPressed: () => _action('weightHistory'),
                          ),
                        ],
                        if (snapshot.bodyFatHistoryCount > 0) ...[
                          const SizedBox(height: NeoMetrics.sectionSpacing),
                          _HistoryLink(
                            colors: colors,
                            title: snapshot.strings['bodyFatHistory'],
                            count: snapshot.bodyFatHistoryCount,
                            strings: snapshot.strings,
                            acidIcon: true,
                            onPressed: () => _action('bodyFatHistory'),
                          ),
                        ],
                        if (snapshot.workoutHistoryCount > 0) ...[
                          const SizedBox(height: NeoMetrics.sectionSpacing),
                          _HistoryLink(
                            colors: colors,
                            title: snapshot.strings['workoutHistory'],
                            count: snapshot.workoutHistoryCount,
                            strings: snapshot.strings,
                            acidIcon: false,
                            icon: Icons.fitness_center,
                            onPressed: () => _action('workoutHistory'),
                          ),
                        ],
                        const SizedBox(height: NeoMetrics.sectionSpacing),
                        _CaloriesPanel(colors: colors, snapshot: snapshot),
                        const SizedBox(height: NeoMetrics.sectionSpacing),
                        _MacroPanel(colors: colors, snapshot: snapshot),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({
    required this.colors,
    required this.error,
    required this.retry,
  });
  final NeoColors colors;
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return Center(child: CupertinoActivityIndicator(color: colors.cobalt));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeoPanel(
          colors: colors,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PROGRESS UNAVAILABLE',
                style: neoText(
                  17,
                  FontWeight.w900,
                  colors.ink,
                  condensed: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: neoText(12, FontWeight.w600, colors.mutedInk),
              ),
              const SizedBox(height: 14),
              NeoActionButton(
                colors: colors,
                title: 'RETRY',
                icon: Icons.refresh,
                onPressed: retry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.strings});
  final NeoColors colors;
  final ProgressStrings strings;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      colors: colors,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings['eyebrow'],
                  style: neoText(
                    11,
                    FontWeight.w900,
                    colors.cobalt,
                    letterSpacing: .2,
                    condensed: true,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings['title'],
                  maxLines: 1,
                  style: neoText(
                    34,
                    FontWeight.w900,
                    colors.ink,
                    height: 1,
                    condensed: true,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  strings['subtitle'],
                  maxLines: 2,
                  style: neoText(
                    13,
                    FontWeight.w700,
                    colors.mutedInk,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.cobalt,
              border: Border.all(color: colors.ink, width: NeoMetrics.rule),
            ),
            child: Icon(Icons.show_chart, color: colors.onCobalt, size: 27),
          ),
        ],
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.colors,
    required this.selected,
    required this.onChanged,
  });
  final NeoColors colors;
  final ProgressRange selected;
  final ValueChanged<ProgressRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.ink, width: NeoMetrics.rule),
      ),
      child: Row(
        children: [
          for (final item in ProgressRange.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('progress.range.${item.channelValue}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(item),
                child: Semantics(
                  container: true,
                  button: true,
                  selected: item == selected,
                  label: item.label,
                  identifier: 'progress.range.${item.channelValue}',
                  onTap: () => onChanged(item),
                  child: ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item == selected ? colors.cobalt : colors.subtle,
                        border: Border.all(
                          color: item == selected
                              ? colors.ink
                              : colors.ink.withValues(alpha: .22),
                        ),
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: neoText(
                          11,
                          FontWeight.w900,
                          item == selected ? colors.onCobalt : colors.ink,
                          condensed: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricPicker extends StatelessWidget {
  const _MetricPicker({
    required this.colors,
    required this.strings,
    required this.selected,
    required this.onChanged,
  });
  final NeoColors colors;
  final ProgressStrings strings;
  final _BodyMetric selected;
  final ValueChanged<_BodyMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.subtle,
        border: Border.all(color: colors.ink),
      ),
      child: Row(
        children: _BodyMetric.values
            .map((metric) {
              final active = selected == metric;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(metric),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    alignment: Alignment.center,
                    color: active ? colors.cobalt : const Color(0x00000000),
                    child: Text(
                      metric == _BodyMetric.weight
                          ? strings['weight']
                          : strings['bodyFat'],
                      style: neoText(
                        12,
                        FontWeight.w900,
                        active ? colors.onCobalt : colors.ink,
                        condensed: true,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _WeightPanel extends StatelessWidget {
  const _WeightPanel({
    required this.colors,
    required this.snapshot,
    required this.onLog,
  });
  final NeoColors colors;
  final ProgressSnapshot snapshot;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final unit = snapshot.weightUnit;
    String formatted(double? value, {bool signed = false}) {
      if (value == null) return '—';
      final prefix = signed && value > 0 ? '+' : '';
      return '$prefix${value.toStringAsFixed(1)} $unit';
    }

    final samples = snapshot.weightEntries;
    final change = samples.length > 1
        ? samples.last.value - samples.first.value
        : 0.0;
    final average = samples.isEmpty
        ? null
        : samples.map((e) => e.value).reduce((a, b) => a + b) / samples.length;
    return _TrendPanel(
      colors: colors,
      title: snapshot.strings['weight'],
      actionTitle: snapshot.strings['logWeight'],
      emptyText: snapshot.strings['emptyWeight'],
      actionIdentifier: 'progress.logWeight',
      samples: samples,
      goal: snapshot.goalWeight,
      onLog: onLog,
      badges: [
        _BadgeData(
          snapshot.strings['current'],
          formatted(snapshot.currentWeight),
        ),
        if (snapshot.goalWeight != null)
          _BadgeData(snapshot.strings['goal'], formatted(snapshot.goalWeight)),
        _BadgeData(
          snapshot.strings['netChange'],
          formatted(change, signed: true),
        ),
        _BadgeData(snapshot.strings['average'], formatted(average)),
      ],
    );
  }
}

class _BodyFatPanel extends StatelessWidget {
  const _BodyFatPanel({
    required this.colors,
    required this.snapshot,
    required this.onLog,
  });
  final NeoColors colors;
  final ProgressSnapshot snapshot;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    String formatted(double? value, {bool signed = false}) {
      if (value == null) return '—';
      final prefix = signed && value > 0 ? '+' : '';
      return '$prefix${value.toStringAsFixed(1)}%';
    }

    final samples = snapshot.bodyFatEntries;
    final change = samples.length > 1
        ? samples.last.value - samples.first.value
        : 0.0;
    final average = samples.isEmpty
        ? null
        : samples.map((e) => e.value).reduce((a, b) => a + b) / samples.length;
    return _TrendPanel(
      colors: colors,
      title: snapshot.strings['bodyFat'],
      actionTitle: snapshot.strings['logBodyFat'],
      emptyText: snapshot.strings['emptyBodyFat'],
      actionIdentifier: 'progress.logBodyFat',
      samples: samples,
      goal: snapshot.goalBodyFat,
      onLog: onLog,
      badges: [
        _BadgeData(
          snapshot.strings['current'],
          formatted(snapshot.currentBodyFat),
        ),
        if (snapshot.goalBodyFat != null)
          _BadgeData(snapshot.strings['goal'], formatted(snapshot.goalBodyFat)),
        _BadgeData(
          snapshot.strings['netChange'],
          formatted(change, signed: true),
        ),
        _BadgeData(snapshot.strings['average'], formatted(average)),
      ],
    );
  }
}

class _BadgeData {
  const _BadgeData(this.label, this.value);
  final String label;
  final String value;
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.colors,
    required this.title,
    required this.actionTitle,
    required this.emptyText,
    required this.actionIdentifier,
    required this.samples,
    required this.goal,
    required this.badges,
    required this.onLog,
  });
  final NeoColors colors;
  final String title;
  final String actionTitle;
  final String emptyText;
  final String actionIdentifier;
  final List<TrendSample> samples;
  final double? goal;
  final List<_BadgeData> badges;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: neoText(
                    17,
                    FontWeight.w900,
                    colors.ink,
                    condensed: true,
                  ),
                ),
              ),
              NeoActionButton(
                colors: colors,
                title: actionTitle,
                icon: Icons.add_circle,
                semanticIdentifier: actionIdentifier,
                onPressed: onLog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (samples.isEmpty)
            _EmptyState(colors: colors, text: emptyText)
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: badges
                  .map((badge) => _StatBadge(colors: colors, data: badge))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  colors: colors,
                  samples: samples,
                  goal: goal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.colors, required this.data});
  final NeoColors colors;
  final _BadgeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.subtle,
        border: Border.all(color: colors.ink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: neoText(9, FontWeight.w900, colors.cobalt, condensed: true),
          ),
          Text(data.value, style: neoText(11, FontWeight.w800, colors.ink)),
        ],
      ),
    );
  }
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({
    required this.colors,
    required this.title,
    required this.count,
    required this.strings,
    required this.acidIcon,
    required this.onPressed,
    this.icon = Icons.view_list,
  });
  final NeoColors colors;
  final String title;
  final int count;
  final ProgressStrings strings;
  final bool acidIcon;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? strings['entry'] : strings['entries'];
    return Semantics(
      container: true,
      button: true,
      label: title,
      identifier: 'progress.history.${title.toLowerCase().replaceAll(' ', '')}',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: NeoPanel(
            colors: colors,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  color: acidIcon ? NeoPalette.acid : colors.cobalt,
                  child: Icon(
                    icon,
                    size: 17,
                    color: acidIcon ? const Color(0xFF000000) : colors.onCobalt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: neoText(
                          16,
                          FontWeight.w900,
                          colors.ink,
                          condensed: true,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count $countLabel · ${strings['tapToView']}',
                        style: neoText(12, FontWeight.w500, colors.mutedInk),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 15,
                  color: colors.cobalt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaloriesPanel extends StatelessWidget {
  const _CaloriesPanel({required this.colors, required this.snapshot});
  final NeoColors colors;
  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final values = snapshot.dailyCalories;
    final average = values.isEmpty
        ? 0
        : values.fold<int>(0, (sum, item) => sum + item.calories) ~/
              values.length;
    return NeoPanel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.strings['calories'],
                  style: neoText(
                    17,
                    FontWeight.w900,
                    colors.ink,
                    condensed: true,
                  ),
                ),
              ),
              if (values.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  color: NeoPalette.acid,
                  child: Text(
                    '${snapshot.strings['averagePrefix']}: $average kcal',
                    style: neoText(
                      11,
                      FontWeight.w900,
                      const Color(0xFF000000),
                      condensed: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (values.isEmpty)
            _EmptyState(colors: colors, text: snapshot.strings['noFood'])
          else
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _CaloriesPainter(
                  colors: colors,
                  values: values,
                  goal: snapshot.calorieGoal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroPanel extends StatelessWidget {
  const _MacroPanel({required this.colors, required this.snapshot});
  final NeoColors colors;
  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.strings['macroAverages'],
            style: neoText(17, FontWeight.w900, colors.ink, condensed: true),
          ),
          const SizedBox(height: 12),
          _MacroRow(
            colors: colors,
            label: snapshot.strings['protein'],
            current: snapshot.averageProtein,
            goal: snapshot.proteinGoal,
            fill: colors.cobalt,
          ),
          const SizedBox(height: 12),
          _MacroRow(
            colors: colors,
            label: snapshot.strings['carbs'],
            current: snapshot.averageCarbs,
            goal: snapshot.carbsGoal,
            fill: NeoPalette.acid,
          ),
          const SizedBox(height: 12),
          _MacroRow(
            colors: colors,
            label: snapshot.strings['fat'],
            current: snapshot.averageFat,
            goal: snapshot.fatGoal,
            fill: colors.cobaltDeep,
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.colors,
    required this.label,
    required this.current,
    required this.goal,
    required this.fill,
  });
  final NeoColors colors;
  final String label;
  final double current;
  final int goal;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: neoText(
                  12,
                  FontWeight.w900,
                  colors.ink,
                  condensed: true,
                ),
              ),
            ),
            Text(
              '${current.toStringAsFixed(1)}g / ${goal}g',
              style: neoText(12, FontWeight.w700, colors.mutedInk),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 10,
            decoration: BoxDecoration(
              color: colors.subtle,
              border: Border.all(color: colors.ink),
            ),
            alignment: Alignment.centerLeft,
            child: Container(
              width: math.max(4, constraints.maxWidth * progress),
              color: fill,
            ),
          ),
        ),
      ],
    );
  }
}

class NeoPanel extends StatelessWidget {
  const NeoPanel({
    super.key,
    required this.colors,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final NeoColors colors;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.ink, width: NeoMetrics.rule),
      ),
      child: child,
    );
  }
}

class NeoActionButton extends StatelessWidget {
  const NeoActionButton({
    super.key,
    required this.colors,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.semanticIdentifier,
  });
  final NeoColors colors;
  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: title,
      identifier: semanticIdentifier,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: CupertinoButton(
          minimumSize: Size.zero,
          pressedOpacity: .68,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: NeoPalette.acid,
              border: Border.all(color: colors.ink),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFF000000)),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: neoText(
                    11,
                    FontWeight.w900,
                    const Color(0xFF000000),
                    condensed: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.text});
  final NeoColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      color: colors.subtle,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: neoText(13, FontWeight.w700, colors.mutedInk),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.colors,
    required this.samples,
    required this.goal,
  });
  final NeoColors colors;
  final List<TrendSample> samples;
  final double? goal;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 7.0;
    const top = 8.0;
    const bottom = 24.0;
    final plot = Rect.fromLTRB(left, top, size.width - 5, size.height - bottom);
    final values = [...samples.map((e) => e.value), ?goal];
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    final padding = math.max((maxValue - minValue) * .15, 2.0);
    minValue -= padding;
    maxValue += padding;
    final grid = Paint()
      ..color = colors.ink.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    double xAt(int index) => samples.length == 1
        ? plot.center.dx
        : plot.left + plot.width * index / (samples.length - 1);
    double yAt(double value) =>
        plot.bottom - (value - minValue) / (maxValue - minValue) * plot.height;
    if (goal case final target?) {
      _drawDashedLine(
        canvas,
        Offset(plot.left, yAt(target)),
        Offset(plot.right, yAt(target)),
        Paint()
          ..color = NeoPalette.success
          ..strokeWidth = 1.5,
      );
    }
    final path = Path();
    for (var index = 0; index < samples.length; index++) {
      final point = Offset(xAt(index), yAt(samples[index].value));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.cobalt
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    if (samples.length <= 31) {
      final dot = Paint()..color = colors.cobalt;
      for (var index = 0; index < samples.length; index++) {
        canvas.drawCircle(
          Offset(xAt(index), yAt(samples[index].value)),
          3,
          dot,
        );
      }
    }
    _paintDateLabels(
      canvas,
      plot,
      samples.map((e) => e.date).toList(growable: false),
      colors,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.goal != goal ||
      oldDelegate.colors != colors;
}

class _CaloriesPainter extends CustomPainter {
  const _CaloriesPainter({
    required this.colors,
    required this.values,
    required this.goal,
  });
  final NeoColors colors;
  final List<CalorieSample> values;
  final int goal;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 5.0;
    const top = 8.0;
    const bottom = 24.0;
    final plot = Rect.fromLTRB(left, top, size.width - 5, size.height - bottom);
    final maxValue =
        math.max(
          goal.toDouble(),
          values.map((e) => e.calories.toDouble()).reduce(math.max),
        ) *
        1.12;
    final slot = plot.width / values.length;
    final barWidth = math.max(2.0, math.min(18.0, slot * .68));
    final paint = Paint()..color = colors.cobalt;
    for (var index = 0; index < values.length; index++) {
      final height =
          plot.height * values[index].calories / math.max(maxValue, 1);
      final x = plot.left + slot * (index + .5);
      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, plot.bottom - height, barWidth, height),
        paint,
      );
    }
    final goalY = plot.bottom - plot.height * goal / math.max(maxValue, 1);
    _drawDashedLine(
      canvas,
      Offset(plot.left, goalY),
      Offset(plot.right, goalY),
      Paint()
        ..color = colors.ink.withValues(alpha: .7)
        ..strokeWidth = 1.5,
    );
    _paintDateLabels(
      canvas,
      plot,
      values.map((e) => e.date).toList(growable: false),
      colors,
    );
  }

  @override
  bool shouldRepaint(covariant _CaloriesPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.goal != goal ||
      oldDelegate.colors != colors;
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 6.0;
  const gap = 4.0;
  var x = start.dx;
  while (x < end.dx) {
    canvas.drawLine(
      Offset(x, start.dy),
      Offset(math.min(x + dash, end.dx), end.dy),
      paint,
    );
    x += dash + gap;
  }
}

void _paintDateLabels(
  Canvas canvas,
  Rect plot,
  List<DateTime> dates,
  NeoColors colors,
) {
  if (dates.isEmpty) return;
  final indices = dates.length == 1
      ? <int>[0]
      : <int>[0, dates.length ~/ 2, dates.length - 1];
  for (final index in indices.toSet()) {
    final date = dates[index];
    final label = '${_monthNames[date.month - 1]} ${date.day}';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: neoText(9, FontWeight.w600, colors.mutedInk),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = dates.length == 1
        ? plot.center.dx
        : plot.left + plot.width * index / (dates.length - 1);
    painter.paint(
      canvas,
      Offset(
        (x - painter.width / 2).clamp(0, plot.right - painter.width),
        plot.bottom + 6,
      ),
    );
  }
}

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
