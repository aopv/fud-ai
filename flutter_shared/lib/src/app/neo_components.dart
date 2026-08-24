import 'package:flutter/material.dart';

import '../theme/neo_theme.dart' hide NeoColors;

class NeoColors {
  const NeoColors._();

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? NeoPalette.canvasDark
      : NeoPalette.canvasLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? NeoPalette.surfaceDark
      : NeoPalette.surfaceLight;

  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? NeoPalette.inkDark
      : NeoPalette.inkLight;

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? NeoPalette.mutedDark
      : NeoPalette.mutedLight;

  static Color get cobalt => NeoPalette.cobaltLight;
  static Color get acid => NeoPalette.acid;
}

class NeoPage extends StatelessWidget {
  const NeoPage({
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    super.key,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NeoColors.canvas(context),
      child: SafeArea(
        bottom: false,
        child: ListView(
          controller: controller,
          padding: padding,
          children: children,
        ),
      ),
    );
  }
}

class NeoHeader extends StatelessWidget {
  const NeoHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.eyebrow,
    this.trailing,
    super.key,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return NeoFrame(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      color: NeoColors.cobalt,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: NeoColors.ink(context),
                    fontSize: 38,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: NeoColors.muted(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          trailing ?? NeoIconTile(icon: icon),
        ],
      ),
    );
  }
}

class NeoFrame extends StatelessWidget {
  const NeoFrame({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.borderWidth = 2,
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? NeoColors.surface(context),
        border: Border.all(color: NeoColors.ink(context), width: borderWidth),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class NeoIconTile extends StatelessWidget {
  const NeoIconTile({
    required this.icon,
    this.color,
    this.size = 58,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: color ?? NeoColors.cobalt,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: NeoColors.ink(context), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: size * 0.48),
        ),
      ),
    );
  }
}

class NeoSectionLabel extends StatelessWidget {
  const NeoSectionLabel(
    this.text, {
    this.color,
    this.textColor = Colors.black,
    super.key,
  });

  final String text;
  final Color? color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color ?? NeoColors.acid,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class NeoButton extends StatelessWidget {
  const NeoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? NeoColors.acid,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: NeoColors.ink(context), width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 15,
            vertical: compact ? 9 : 14,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.black, size: compact ? 18 : 23),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: compact ? 13 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NeoActionItem {
  const NeoActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}

Future<void> showNeoActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<NeoActionItem> items,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: NeoColors.canvas(sheetContext),
        border: Border(
          top: BorderSide(color: NeoColors.ink(sheetContext), width: 3),
          left: BorderSide(color: NeoColors.ink(sheetContext), width: 3),
          right: BorderSide(color: NeoColors.ink(sheetContext), width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: NeoColors.ink(sheetContext),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: NeoColors.muted(sheetContext),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                NeoIconTile(
                  icon: Icons.close,
                  color: Colors.black,
                  size: 44,
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeoFrame(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      item.onTap();
                    });
                  },
                  color: item.destructive ? Colors.red : null,
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      NeoIconTile(
                        icon: item.icon,
                        color: item.destructive
                            ? Colors.black
                            : NeoColors.cobalt,
                        size: 44,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label.toUpperCase(),
                              style: TextStyle(
                                color: item.destructive
                                    ? Colors.white
                                    : NeoColors.ink(sheetContext),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (item.subtitle != null)
                              Text(
                                item.subtitle!,
                                style: TextStyle(
                                  color: item.destructive
                                      ? Colors.white70
                                      : NeoColors.muted(sheetContext),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: item.destructive
                            ? Colors.white
                            : NeoColors.ink(sheetContext),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NeoEmpty extends StatelessWidget {
  const NeoEmpty({required this.text, this.icon = Icons.add, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return NeoFrame(
      color: NeoColors.ink(context).withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        children: [
          Icon(icon, color: NeoColors.cobalt, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeoColors.muted(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class NeoLoading extends StatelessWidget {
  const NeoLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NeoColors.canvas(context),
      child: Center(
        child: SizedBox.square(
          dimension: 44,
          child: CircularProgressIndicator(
            color: NeoColors.cobalt,
            strokeWidth: 5,
          ),
        ),
      ),
    );
  }
}

String formatNumber(num value, {int decimals = 0}) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(decimals);
}
