import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeExtension;

abstract final class NeoPalette {
  static const canvasLight = Color(0xFFF9F6EC);
  static const surfaceLight = Color(0xFFFFFEF9);
  static const subtleLight = Color(0xFFF0EDE0);
  static const inkLight = Color(0xFF000000);
  static const mutedLight = Color(0xFF474747);
  static const cobaltLight = Color(0xFF063BEB);
  static const cobaltDeepLight = Color(0xFF0026B8);

  static const canvasDark = Color(0xFF010102);
  static const surfaceDark = Color(0xFF060608);
  static const subtleDark = Color(0xFF131313);
  static const inkDark = Color(0xFFFFFFFF);
  static const mutedDark = Color(0xFFADADAD);
  static const cobaltDark = Color(0xFF4D78FF);
  static const cobaltDeepDark = Color(0xFF0E38BD);

  static const acid = Color(0xFFEEFF00);
  static const success = Color(0xFF30D17A);
}

@immutable
class NeoColors extends ThemeExtension<NeoColors> {
  const NeoColors({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.ink,
    required this.mutedInk,
    required this.cobalt,
    required this.cobaltDeep,
    required this.onCobalt,
  });

  factory NeoColors.forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const NeoColors(
        canvas: NeoPalette.canvasDark,
        surface: NeoPalette.surfaceDark,
        subtle: NeoPalette.subtleDark,
        ink: NeoPalette.inkDark,
        mutedInk: NeoPalette.mutedDark,
        cobalt: NeoPalette.cobaltDark,
        cobaltDeep: NeoPalette.cobaltDeepDark,
        onCobalt: Color(0xFF000000),
      );
    }
    return const NeoColors(
      canvas: NeoPalette.canvasLight,
      surface: NeoPalette.surfaceLight,
      subtle: NeoPalette.subtleLight,
      ink: NeoPalette.inkLight,
      mutedInk: NeoPalette.mutedLight,
      cobalt: NeoPalette.cobaltLight,
      cobaltDeep: NeoPalette.cobaltDeepLight,
      onCobalt: Color(0xFFFFFFFF),
    );
  }

  final Color canvas;
  final Color surface;
  final Color subtle;
  final Color ink;
  final Color mutedInk;
  final Color cobalt;
  final Color cobaltDeep;
  final Color onCobalt;

  @override
  NeoColors copyWith({
    Color? canvas,
    Color? surface,
    Color? subtle,
    Color? ink,
    Color? mutedInk,
    Color? cobalt,
    Color? cobaltDeep,
    Color? onCobalt,
  }) {
    return NeoColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      subtle: subtle ?? this.subtle,
      ink: ink ?? this.ink,
      mutedInk: mutedInk ?? this.mutedInk,
      cobalt: cobalt ?? this.cobalt,
      cobaltDeep: cobaltDeep ?? this.cobaltDeep,
      onCobalt: onCobalt ?? this.onCobalt,
    );
  }

  @override
  NeoColors lerp(ThemeExtension<NeoColors>? other, double t) {
    if (other is! NeoColors) return this;
    return NeoColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      cobalt: Color.lerp(cobalt, other.cobalt, t)!,
      cobaltDeep: Color.lerp(cobaltDeep, other.cobaltDeep, t)!,
      onCobalt: Color.lerp(onCobalt, other.onCobalt, t)!,
    );
  }
}

abstract final class NeoMetrics {
  static const screenInset = 14.0;
  static const sectionSpacing = 14.0;
  static const rule = 2.0;
  static const compactRule = 1.0;
}

TextStyle neoText(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
  bool condensed = false,
}) {
  return TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontVariations: condensed ? const [FontVariation('wdth', 78)] : null,
  );
}
