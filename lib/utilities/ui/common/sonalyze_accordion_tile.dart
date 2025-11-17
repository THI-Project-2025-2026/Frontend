import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:sonalyze_frontend/utilities/ui/common/sonalyze_surface.dart';

/// Reusable accordion tile that expands and collapses within a SonalyzeSurface.
class SonalyzeAccordionTile extends StatelessWidget {
  const SonalyzeAccordionTile({
    super.key,
    required this.title,
    required this.body,
    required this.isExpanded,
    required this.onToggle,
    required this.backgroundColor,
    this.expandedBorderColor,
    this.collapsedBorderColor,
    this.iconColor,
    this.titleStyle,
    this.bodyStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.borderWidth = 1.2,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOut,
  });

  final String title;
  final String body;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color backgroundColor;
  final Color? expandedBorderColor;
  final Color? collapsedBorderColor;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final defaultBorderColor = AppConstants.getThemeColor(
      'landing_page.feature_card_selected_border',
    );
    final expandedColor = expandedBorderColor ?? defaultBorderColor;
    final collapsedColor =
        collapsedBorderColor ?? expandedColor.withValues(alpha: 0.35);
    final resolvedBorderColor = isExpanded ? expandedColor : collapsedColor;

    return SonalyzeSurface(
      margin: margin,
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderColor: resolvedBorderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      duration: duration,
      curve: curve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onToggle,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text(title, style: titleStyle)),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: duration,
                      curve: curve,
                      child: Icon(
                        Icons.expand_more,
                        color:
                            iconColor ??
                            Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(body, style: bodyStyle),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: duration,
                  sizeCurve: curve,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
