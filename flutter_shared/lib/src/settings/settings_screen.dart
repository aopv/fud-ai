import 'package:flutter/material.dart';

import '../app/neo_components.dart';

class SharedSettingsScreen extends StatelessWidget {
  const SharedSettingsScreen({
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

  @override
  Widget build(BuildContext context) {
    final sections = (snapshot['sections'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return NeoPage(
      children: [
        NeoHeader(
          eyebrow: 'Make it yours',
          title: 'Settings',
          subtitle: 'Profile, targets, AI, integrations, and privacy',
          icon: Icons.settings,
          trailing: NeoIconTile(
            icon: Icons.person,
            color: NeoColors.acid,
            onTap: () => perform('settings.openProfile'),
          ),
        ),
        const SizedBox(height: 14),
        if (sections.isEmpty)
          const NeoEmpty(text: 'Settings are loading.', icon: Icons.settings)
        else
          ...sections.expand(
            (section) => [
              _SettingsSection(section: section, perform: perform),
              const SizedBox(height: 13),
            ],
          ),
        NeoFrame(
          color: NeoColors.cobalt,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FÜD AI 7.0',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'YOUR DATA STAYS YOURS.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock, color: NeoColors.acid, size: 34),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.section, required this.perform});

  final Map<Object?, Object?> section;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final rows = (section['rows'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return NeoFrame(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          NeoSectionLabel(section['title'] as String? ?? 'Settings'),
          ...rows.indexed.map((indexed) {
            return _SettingsRow(
              row: indexed.$2,
              showDivider: indexed.$1 != rows.length - 1,
              perform: perform,
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.row,
    required this.showDivider,
    required this.perform,
  });

  final Map<Object?, Object?> row;
  final bool showDivider;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final type = row['type'] as String? ?? 'navigation';
    final enabled = row['enabled'] as bool? ?? true;
    final destructive = row['destructive'] as bool? ?? false;
    final id = row['id'] as String? ?? '';
    final titleColor = destructive ? Colors.red : NeoColors.ink(context);
    final choices = (row['choices'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();

    void openRow() {
      if (choices.isNotEmpty) {
        showNeoActionSheet(
          context,
          title: row['title'] as String? ?? 'Choose',
          subtitle: 'Current: ${row['value'] ?? ''}',
          items: choices
              .map(
                (choice) => NeoActionItem(
                  label: choice['label'] as String? ?? '',
                  icon: Icons.check,
                  onTap: () => perform(
                    'settings.choice',
                    arguments: {
                      'id': id,
                      'value': choice['value'] as String? ?? '',
                    },
                  ),
                ),
              )
              .toList(),
        );
        return;
      }
      perform('settings.open', arguments: {'id': id});
    }

    return InkWell(
      onTap: !enabled || type == 'toggle' ? null : openRow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: NeoColors.ink(context), width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              color: destructive ? Colors.red : NeoColors.cobalt,
              child: Icon(
                _settingsIcon(row['icon'] as String?),
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (row['title'] as String? ?? '').toUpperCase(),
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if ((row['subtitle'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      row['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeoColors.muted(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if ((row['value'] as String? ?? '').isNotEmpty)
              Flexible(
                child: Text(
                  (row['value'] as String).toUpperCase(),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NeoColors.cobalt,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            if (type == 'toggle') ...[
              const SizedBox(width: 8),
              Switch(
                value: row['valueBool'] as bool? ?? false,
                activeThumbColor: Colors.black,
                activeTrackColor: NeoColors.acid,
                inactiveThumbColor: NeoColors.muted(context),
                inactiveTrackColor: NeoColors.ink(context)
                    .withValues(alpha: 0.12),
                onChanged: !enabled
                    ? null
                    : (value) => perform(
                        'settings.toggle',
                        arguments: {'id': id, 'value': value},
                      ),
              ),
            ] else ...[
              const SizedBox(width: 7),
              Icon(Icons.chevron_right, color: titleColor),
            ],
          ],
        ),
      ),
    );
  }

  IconData _settingsIcon(String? name) => switch (name) {
    'person' => Icons.person,
    'target' => Icons.gps_fixed,
    'scale' => Icons.monitor_weight,
    'nutrition' => Icons.restaurant,
    'water' => Icons.water_drop,
    'fasting' => Icons.timer,
    'ai' => Icons.auto_awesome,
    'speech' => Icons.mic,
    'notification' => Icons.notifications,
    'health' => Icons.favorite,
    'workout' => Icons.fitness_center,
    'appearance' => Icons.palette,
    'data' => Icons.storage,
    'privacy' => Icons.lock,
    'info' => Icons.info,
    'delete' => Icons.delete_forever,
    _ => Icons.tune,
  };
}
