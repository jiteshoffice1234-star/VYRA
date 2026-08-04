import 'package:flutter/material.dart';

/// Per-style design tokens that widgets use to adapt between VYRA's theme
/// styles (Modern, NeoBrutalism, Glass) beyond what ThemeData can express:
/// corner radius, card borders, hard offset shadows and label casing.
class VyraStyle extends ThemeExtension<VyraStyle> {
  const VyraStyle({
    required this.radius,
    this.border,
    this.hardShadow,
    this.uppercaseLabels = false,
    this.quoteGradient = true,
  });

  /// Corner radius applied to cards, chips and bubbles.
  final double radius;

  /// Card border. `null` means widgets fall back to their default border.
  final BorderSide? border;

  /// A hard offset shadow (the NeoBrutalism look). `null` = soft/no shadow.
  final BoxShadow? hardShadow;

  /// Whether section titles should be rendered UPPERCASE.
  final bool uppercaseLabels;

  /// Whether the quote card uses a gradient (Modern) or a flat fill.
  final bool quoteGradient;

  static const modern = VyraStyle(radius: 20);
  static const neobrutalism = VyraStyle(
    radius: 10,
    uppercaseLabels: true,
    quoteGradient: false,
  );
  static const glass = VyraStyle(radius: 26, quoteGradient: false);

  static VyraStyle of(BuildContext context) =>
      Theme.of(context).extension<VyraStyle>() ?? modern;

  @override
  VyraStyle copyWith({
    double? radius,
    BorderSide? border,
    BoxShadow? hardShadow,
    bool? uppercaseLabels,
    bool? quoteGradient,
  }) =>
      VyraStyle(
        radius: radius ?? this.radius,
        border: border ?? this.border,
        hardShadow: hardShadow ?? this.hardShadow,
        uppercaseLabels: uppercaseLabels ?? this.uppercaseLabels,
        quoteGradient: quoteGradient ?? this.quoteGradient,
      );

  @override
  VyraStyle lerp(covariant VyraStyle? other, double t) {
    if (other == null) return this;
    return VyraStyle(
      radius: radius + (other.radius - radius) * t,
      border: BorderSide.lerp(
        border ?? BorderSide.none,
        other.border ?? BorderSide.none,
        t,
      ),
      hardShadow: t < 0.5 ? hardShadow : other.hardShadow,
      uppercaseLabels: t < 0.5 ? uppercaseLabels : other.uppercaseLabels,
      quoteGradient: t < 0.5 ? quoteGradient : other.quoteGradient,
    );
  }
}
