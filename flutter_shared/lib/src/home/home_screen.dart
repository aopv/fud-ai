import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/neo_components.dart';

class SharedHomeScreen extends StatelessWidget {
  const SharedHomeScreen({
    required this.snapshot,
    required this.perform,
    super.key,
  });

  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  num _number(String key) => snapshot[key] as num? ?? 0;

  Future<void> _openCalendar(BuildContext context) async {
    final current =
        DateTime.tryParse(snapshot['date'] as String? ?? '') ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: NeoColors.cobalt,
            secondary: NeoColors.acid,
            surface: NeoColors.canvas(context),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: NeoColors.ink(context), width: 3),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null) {
      await perform(
        'home.selectDate',
        arguments: {'date': selected.toIso8601String().split('T').first},
      );
    }
  }

  void _openQuickAction(String action) {
    perform('home.quickAction', arguments: {'quickAction': action});
  }

  void _showAddFood(BuildContext context) {
    showNeoActionSheet(
      context,
      title: 'Add Food',
      subtitle: 'Choose how you want to log this meal',
      items: [
        NeoActionItem(
          label: 'Photo & Scan',
          subtitle: 'Camera, photo library, or barcode',
          icon: Icons.add_a_photo,
          onTap: () => _showPhotoActions(context),
        ),
        NeoActionItem(
          label: 'Describe Meal',
          subtitle: 'Type, speak, or enter macros manually',
          icon: Icons.edit_note,
          onTap: () => _showDescribeActions(context),
        ),
        NeoActionItem(
          label: 'Reuse Meal',
          subtitle: 'Recent, frequent, and favorite foods',
          icon: Icons.bookmark,
          onTap: () => _showReuseActions(context),
        ),
      ],
    );
  }

  void _showPhotoActions(BuildContext context) {
    showNeoActionSheet(
      context,
      title: 'Photo & Scan',
      items: [
        NeoActionItem(
          label: 'Camera',
          subtitle: 'Capture a meal with flash support',
          icon: Icons.camera_alt,
          onTap: () => _openQuickAction('CAMERA'),
        ),
        NeoActionItem(
          label: 'Photos',
          subtitle: 'Choose up to 10 photos',
          icon: Icons.photo_library,
          onTap: () => _openQuickAction('PHOTOS'),
        ),
        NeoActionItem(
          label: 'Barcode',
          subtitle: 'Scan a packaged food',
          icon: Icons.qr_code_scanner,
          onTap: () => _openQuickAction('BARCODE'),
        ),
      ],
    );
  }

  void _showDescribeActions(BuildContext context) {
    showNeoActionSheet(
      context,
      title: 'Describe Meal',
      items: [
        NeoActionItem(
          label: 'Type Description',
          icon: Icons.keyboard,
          onTap: () => _openQuickAction('TEXT'),
        ),
        NeoActionItem(
          label: 'Voice Description',
          icon: Icons.mic,
          onTap: () => _openQuickAction('VOICE'),
        ),
        NeoActionItem(
          label: 'Manual Macros',
          icon: Icons.edit,
          onTap: () => _openQuickAction('MANUAL'),
        ),
      ],
    );
  }

  void _showReuseActions(BuildContext context) {
    showNeoActionSheet(
      context,
      title: 'Reuse Meal',
      items: [
        NeoActionItem(
          label: 'Recent',
          icon: Icons.history,
          onTap: () => _openQuickAction('RECENT'),
        ),
        NeoActionItem(
          label: 'Frequent',
          icon: Icons.repeat,
          onTap: () => _openQuickAction('FREQUENT'),
        ),
        NeoActionItem(
          label: 'Favorites',
          icon: Icons.favorite,
          onTap: () => _openQuickAction('FAVORITES'),
        ),
      ],
    );
  }

  void _showWaterActions(BuildContext context) {
    showNeoActionSheet(
      context,
      title: 'Log Water',
      subtitle: snapshot['waterDisplay'] as String? ?? '',
      items: [250, 500, 750]
          .map(
            (amount) => NeoActionItem(
              label: '$amount ml',
              icon: Icons.water_drop,
              onTap: () =>
                  perform('home.addWater', arguments: {'milliliters': amount}),
            ),
          )
          .toList(),
    );
  }

  void _showFastingActions(BuildContext context) {
    final active = (snapshot['fastingStatus'] as String? ?? '')
        .toLowerCase()
        .contains('progress');
    showNeoActionSheet(
      context,
      title: 'Fasting',
      subtitle: snapshot['fastingStatus'] as String?,
      items: active
          ? [
              NeoActionItem(
                label: 'End Fast',
                icon: Icons.stop,
                onTap: () => perform('home.endFast'),
              ),
              NeoActionItem(
                label: 'Cancel Fast',
                icon: Icons.delete,
                destructive: true,
                onTap: () => perform('home.cancelFast'),
              ),
            ]
          : [12, 14, 16, 18, 20]
                .map(
                  (hours) => NeoActionItem(
                    label: '$hours hour fast',
                    icon: Icons.timer,
                    onTap: () => perform(
                      'home.startFast',
                      arguments: {'minutes': hours * 60},
                    ),
                  ),
                )
                .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calories = _number('calories').toInt();
    final calorieGoal = math.max(1, _number('calorieGoal').toInt());
    final remaining = calorieGoal - calories;
    final groups = (snapshot['mealGroups'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    final waterEnabled = snapshot['waterEnabled'] as bool? ?? false;
    final fastingEnabled = snapshot['fastingEnabled'] as bool? ?? false;

    return NeoPage(
      children: [
        NeoHeader(
          title: snapshot['title'] as String? ?? 'Today',
          subtitle: snapshot['dateLabel'] as String? ?? '',
          icon: Icons.calendar_month,
          trailing: NeoIconTile(
            icon: Icons.calendar_month,
            color: Colors.black,
            onTap: () => _openCalendar(context),
          ),
        ),
        const SizedBox(height: 10),
        _DateStrip(snapshot: snapshot, perform: perform),
        const SizedBox(height: 14),
        SizedBox(
          height: 310,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _CalorieCard(
                  calories: calories,
                  remaining: remaining,
                  goal: calorieGoal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _TargetCard(goal: calorieGoal)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MacroGrid(snapshot: snapshot),
        if (waterEnabled) ...[
          const SizedBox(height: 10),
          _TrackingRow(
            icon: Icons.water_drop,
            title: 'Water',
            value:
                '${snapshot['waterDisplay'] ?? '${_number('waterMl').toInt()} ml'} / ${snapshot['waterGoalDisplay'] ?? '${_number('waterGoalMl').toInt()} ml'}',
            color: NeoColors.cobalt,
            onTap: () => _showWaterActions(context),
          ),
        ],
        if (fastingEnabled) ...[
          const SizedBox(height: 10),
          _TrackingRow(
            icon: Icons.timer,
            title: 'Fasting',
            value: snapshot['fastingStatus'] as String? ?? 'Ready',
            color: NeoColors.acid,
            onTap: () => _showFastingActions(context),
          ),
        ],
        const SizedBox(height: 14),
        NeoButton(
          label: 'Add Food',
          icon: Icons.add,
          onPressed: () => _showAddFood(context),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          NeoEmpty(
            text: 'No food logged for this day. Add your first meal.',
            icon: Icons.restaurant,
          )
        else
          ...groups.expand(
            (group) => [
              _MealGroup(group: group, perform: perform),
              const SizedBox(height: 12),
            ],
          ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.snapshot, required this.perform});

  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final days = (snapshot['weekDays'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return NeoFrame(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Row(
        children: days.map((day) {
          final selected = day['selected'] as bool? ?? false;
          return Expanded(
            child: InkWell(
              onTap: () => perform(
                'home.selectDate',
                arguments: {'date': day['date'] as String? ?? ''},
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: selected ? NeoColors.acid : Colors.transparent,
                child: Column(
                  children: [
                    Text(
                      (day['weekday'] as String? ?? '').toUpperCase(),
                      style: TextStyle(
                        color: selected
                            ? Colors.black
                            : NeoColors.muted(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${day['day'] ?? ''}',
                      style: TextStyle(
                        color: selected ? Colors.black : NeoColors.ink(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({
    required this.calories,
    required this.remaining,
    required this.goal,
  });

  final int calories;
  final int remaining;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final used = (calories / goal).clamp(0.0, 1.0);
    return NeoFrame(
      color: NeoColors.cobalt,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: NeoSectionLabel(
              'Calories',
              color: Colors.black,
              textColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$calories',
                    style: const TextStyle(fontSize: 62),
                  ),
                  const TextSpan(text: ' kcal', style: TextStyle(fontSize: 20)),
                ],
              ),
              style: const TextStyle(
                color: Colors.white,
                height: 0.95,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining >= 0 ? '$remaining LEFT' : '${-remaining} OVER',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                _SegmentMeter(progress: used),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.goal});
  final int goal;

  @override
  Widget build(BuildContext context) {
    return NeoFrame(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Column(
        children: [
          const NeoSectionLabel('Target', color: Colors.white),
          const Spacer(),
          Icon(Icons.gps_fixed, color: NeoColors.cobalt, size: 58),
          const Spacer(),
          FittedBox(
            child: Text(
              '$goal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Text(
            'GOAL\nKCAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentMeter extends StatelessWidget {
  const _SegmentMeter({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(16, (index) {
        final active = index < (progress * 16).ceil();
        return Expanded(
          child: Container(
            height: 18,
            margin: const EdgeInsets.only(right: 3),
            color: active ? Colors.white : Colors.white24,
          ),
        );
      }),
    );
  }
}

class _MacroGrid extends StatelessWidget {
  const _MacroGrid({required this.snapshot});
  final Map<Object?, Object?> snapshot;

  @override
  Widget build(BuildContext context) {
    final macros = [
      ('Protein', Icons.restaurant, 'protein', 'proteinGoal'),
      ('Carbs', Icons.eco, 'carbs', 'carbsGoal'),
      ('Fat', Icons.water_drop, 'fat', 'fatGoal'),
      ('Fiber', Icons.energy_savings_leaf, 'fiber', 'fiberGoal'),
    ];
    return NeoFrame(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: macros.map((macro) {
            final value = snapshot[macro.$3] as num? ?? 0;
            final goal = math.max(
              1,
              (snapshot[macro.$4] as num? ?? 1).toDouble(),
            );
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: macro != macros.last
                        ? BorderSide(color: NeoColors.ink(context), width: 1.5)
                        : BorderSide.none,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      macro.$1.toUpperCase(),
                      style: TextStyle(
                        color: NeoColors.ink(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(macro.$2, color: NeoColors.cobalt, size: 27),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Text(
                        '${formatNumber(value, decimals: 1)}g',
                        style: TextStyle(
                          color: NeoColors.ink(context),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (value.toDouble() / goal).clamp(0, 1),
                      minHeight: 5,
                      color: NeoColors.cobalt,
                      backgroundColor: NeoColors.ink(context)
                          .withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TrackingRow extends StatelessWidget {
  const _TrackingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoFrame(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          NeoIconTile(icon: icon, color: color, size: 43),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: NeoColors.ink(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: NeoColors.muted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: NeoColors.ink(context)),
        ],
      ),
    );
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({required this.group, required this.perform});

  final Map<Object?, Object?> group;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final entries = (group['entries'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return NeoFrame(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            color: NeoColors.acid,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(_mealIcon(group['meal'] as String?), color: Colors.black),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    (group['title'] as String? ?? 'Meal').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${group['calories'] ?? 0} KCAL',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'NOTHING LOGGED',
                style: TextStyle(
                  color: NeoColors.muted(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            ...entries.indexed.map((indexed) {
              final index = indexed.$1;
              final entry = indexed.$2;
              return InkWell(
                onTap: () => perform(
                  'home.openEntry',
                  arguments: {'id': entry['id'] as String? ?? ''},
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: index == entries.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: NeoColors.ink(context),
                              width: 1,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${index + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            color: NeoColors.cobalt,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        entry['emoji'] as String? ?? '🍽️',
                        style: const TextStyle(fontSize: 27),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (entry['name'] as String? ?? 'Food')
                                  .toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: NeoColors.ink(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'P ${formatNumber(entry['protein'] as num? ?? 0, decimals: 1)} · C ${formatNumber(entry['carbs'] as num? ?? 0, decimals: 1)} · F ${formatNumber(entry['fat'] as num? ?? 0, decimals: 1)}',
                              style: TextStyle(
                                color: NeoColors.muted(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: NeoColors.ink(context),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${entry['calories'] ?? 0}\nKCAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NeoColors.ink(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _mealIcon(String? meal) => switch (meal) {
    'breakfast' => Icons.wb_sunny,
    'lunch' => Icons.light_mode,
    'dinner' => Icons.nightlight,
    'snack' => Icons.coffee,
    _ => Icons.restaurant,
  };
}
