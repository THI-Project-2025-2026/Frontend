import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';

/// Reusable rounded surface used across Sonalyze feature pages.
///
/// Provides a consistent container API where callers control padding,
/// colors, and animation characteristics while sharing a common shape.
class SonalyzeSurface extends StatelessWidget {
  const SonalyzeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.alignment,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1.2,
    this.borderRadius,
    this.boxShadow,
    this.constraints,
    this.width,
    this.height,
    this.duration = Duration.zero,
    this.curve = Curves.linear,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;
  final Duration duration;
  final Curve curve;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);
    final defaultBorderColor = AppConstants.getThemeColor(
      'landing_page.feature_card_selected_border',
    );
    final effectiveBorderColor = borderColor ?? defaultBorderColor;
    final shouldPaintBorder = borderWidth > 0 && effectiveBorderColor.a > 0;
    final decoration = BoxDecoration(
      color: gradient == null ? backgroundColor ?? Colors.transparent : null,
      gradient: gradient,
      borderRadius: effectiveRadius,
      border: shouldPaintBorder
          ? Border.all(color: effectiveBorderColor, width: borderWidth)
          : null,
      boxShadow: boxShadow,
    );

    return AnimatedContainer(
      duration: duration,
      curve: curve,
      alignment: alignment,
      padding: padding,
      margin: margin,
      constraints: constraints,
      width: width,
      height: height,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: child,
    );
  }
}
