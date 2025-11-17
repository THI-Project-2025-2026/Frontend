import 'package:flutter/material.dart';

enum SonalyzeButtonVariant { filled, outlined, text }

/// Styled button used across Sonalyze views with configurable colors.
class SonalyzeButton extends StatelessWidget {
  const SonalyzeButton({
    super.key,
    required this.child,
    this.onPressed,
    this.icon,
    this.variant = SonalyzeButtonVariant.filled,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.disabledBorderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.iconSpacing = 12,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Widget? icon;
  final SonalyzeButtonVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Color? disabledBorderColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double iconSpacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBackground =
        backgroundColor ??
        (variant == SonalyzeButtonVariant.filled
            ? colorScheme.primary
            : Colors.transparent);
    final effectiveForeground =
        foregroundColor ??
        (variant == SonalyzeButtonVariant.filled
            ? colorScheme.onPrimary
            : colorScheme.primary);
    final effectiveBorder =
        borderColor ??
        (variant == SonalyzeButtonVariant.outlined
            ? effectiveForeground.withValues(alpha: 0.7)
            : Colors.transparent);
    final disabledBg =
        disabledBackgroundColor ??
        (variant == SonalyzeButtonVariant.filled
            ? effectiveBackground.withValues(alpha: 0.45)
            : Colors.transparent);
    final disabledFg =
        disabledForegroundColor ?? effectiveForeground.withValues(alpha: 0.45);
    final disabledBorder =
        disabledBorderColor ??
        (variant == SonalyzeButtonVariant.outlined
            ? effectiveBorder.withValues(alpha: 0.35)
            : Colors.transparent);

    WidgetStateProperty<T?> resolve<T>(
      T Function() enabled,
      T Function() disabled,
    ) {
      return WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabled();
        }
        return enabled();
      });
    }

    final style = ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      backgroundColor: resolve<Color?>(
        () => variant == SonalyzeButtonVariant.filled
            ? effectiveBackground
            : Colors.transparent,
        () => variant == SonalyzeButtonVariant.filled
            ? disabledBg
            : Colors.transparent,
      ),
      foregroundColor: resolve<Color?>(
        () => effectiveForeground,
        () => disabledFg,
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return effectiveForeground.withValues(alpha: 0.08);
        }
        return null;
      }),
      side: variant == SonalyzeButtonVariant.outlined
          ? resolve<BorderSide?>(
              () => BorderSide(color: effectiveBorder, width: 1.2),
              () => BorderSide(color: disabledBorder, width: 1.2),
            )
          : null,
    );

    Widget contents = child;
    if (icon != null) {
      contents = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          SizedBox(width: iconSpacing),
          Flexible(child: child),
        ],
      );
    }

    return TextButton(onPressed: onPressed, style: style, child: contents);
  }
}
