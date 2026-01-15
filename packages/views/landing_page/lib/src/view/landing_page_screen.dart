import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:core_ui/core_ui.dart';

import '../bloc/landing_page_bloc.dart';
import 'settings_dialog.dart';

/// Landing page entry point wiring the BLoC to the widget tree.
class LandingPageScreen extends StatelessWidget {
  const LandingPageScreen({
    super.key,
    this.onNavigateToMeasurement,
    this.onNavigateToSimulation,
  });

  static const String routeName = '/';
  static const String defaultMeasurementRoute = '/measurement';
  static const String defaultSimulationRoute = '/simulation';

  final void Function(BuildContext context)? onNavigateToMeasurement;
  final void Function(BuildContext context)? onNavigateToSimulation;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LandingPageBloc(),
      child: BlocBuilder<JsonHotReloadBloc, JsonHotReloadState>(
        builder: (context, state) {
          return _LandingPageView(
            onNavigateToMeasurement: onNavigateToMeasurement,
            onNavigateToSimulation: onNavigateToSimulation,
          );
        },
      ),
    );
  }
}

class _LandingPageView extends StatelessWidget {
  const _LandingPageView({
    this.onNavigateToMeasurement,
    this.onNavigateToSimulation,
  });

  final void Function(BuildContext context)? onNavigateToMeasurement;
  final void Function(BuildContext context)? onNavigateToSimulation;

  void _openMeasurement(BuildContext context) {
    if (onNavigateToMeasurement != null) {
      onNavigateToMeasurement!(context);
      return;
    }
    Navigator.of(context).pushNamed(LandingPageScreen.defaultMeasurementRoute);
  }

  void _openSimulation(BuildContext context) {
    if (onNavigateToSimulation != null) {
      onNavigateToSimulation!(context);
      return;
    }
    Navigator.of(context).pushNamed(LandingPageScreen.defaultSimulationRoute);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = _themeColors('landing_page.background_gradient');

    return Scaffold(
      backgroundColor: _themeColor('app.background'),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: backgroundGradient.length >= 2
                  ? LinearGradient(
                      colors: backgroundGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: backgroundGradient.isEmpty
                  ? _themeColor('app.background')
                  : null,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1200;
                  final isMedium = constraints.maxWidth >= 900;
                  final horizontalPadding = isWide
                      ? 96.0
                      : isMedium
                      ? 72.0
                      : 24.0;
                  final verticalPadding = isWide ? 48.0 : 32.0;
                  final sectionSpacing = isWide ? 56.0 : 48.0;

                  return ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all<Color>(
                        _themeColor(
                          'landing_page.scrollbar_thumb',
                        ).withValues(alpha: 0.7),
                      ),
                      thickness: const WidgetStatePropertyAll<double>(6.0),
                      radius: const Radius.circular(999),
                    ),
                    child: ScrollConfiguration(
                      behavior: const _LandingScrollBehavior(),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroSection(
                              isWide: isWide,
                              isMedium: isMedium,
                              onNavigateToMeasurement: _openMeasurement,
                              onNavigateToSimulation: _openSimulation,
                            ),
                            SizedBox(height: sectionSpacing),
                            _FeatureShowcase(
                              isWide: isWide,
                              isMedium: isMedium,
                            ),
                            SizedBox(height: sectionSpacing),
                            _WorkflowSection(isWide: isWide),
                            SizedBox(height: sectionSpacing),
                            _ContactSection(),
                            SizedBox(height: sectionSpacing),
                            _FaqSection(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isWide,
    required this.isMedium,
    required this.onNavigateToMeasurement,
    required this.onNavigateToSimulation,
  });

  final bool isWide;
  final bool isMedium;
  final void Function(BuildContext context) onNavigateToMeasurement;
  final void Function(BuildContext context) onNavigateToSimulation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeBackground = _themeColor(
      'landing_page.hero_badge_background',
    ).withValues(alpha: 0.85);
    final badgeTextColor = _themeColor('landing_page.hero_badge_text');
    final primaryButtonColor = _themeColor(
      'landing_page.hero_primary_button_background',
    );
    final primaryButtonText = _themeColor(
      'landing_page.hero_primary_button_text',
    );
    final secondaryBorderColor = _themeColor(
      'landing_page.hero_secondary_button_border',
    );
    final secondaryButtonText = _themeColor(
      'landing_page.hero_secondary_button_text',
    );
    final cardBackground = _themeColor(
      'landing_page.feature_card_background',
    ).withValues(alpha: 0.9);

    Widget buildButtons() {
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          SonalyzeButton(
            onPressed: () => onNavigateToSimulation(context),
            backgroundColor: primaryButtonColor,
            foregroundColor: primaryButtonText,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            borderRadius: BorderRadius.circular(18),
            child: Text(
              _tr('landing_page.hero.primary_cta'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SonalyzeButton(
            onPressed: () => onNavigateToMeasurement(context),
            variant: SonalyzeButtonVariant.outlined,
            foregroundColor: secondaryButtonText,
            borderColor: secondaryBorderColor,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            borderRadius: BorderRadius.circular(18),
            child: Text(
              _tr('landing_page.hero.secondary_cta'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildCopy() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _tr('landing_page.hero.badge'),
              style: textTheme.labelLarge?.copyWith(
                color: badgeTextColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(height: isMedium ? 24 : 20),
          Text(
            _tr('landing_page.hero.title'),
            style: textTheme.displaySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          SizedBox(height: isMedium ? 20 : 16),
          Text(
            _tr('landing_page.hero.subtitle'),
            style: textTheme.titleMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          SizedBox(height: isMedium ? 28 : 24),
          buildButtons(),
        ],
      );
    }

    return BlocBuilder<LandingPageBloc, LandingPageState>(
      buildWhen: (previous, current) =>
          previous.activeFeatureIndex != current.activeFeatureIndex,
      builder: (context, state) {
        final feature = state.activeFeature;
        final gradient = _themeColors(
          'landing_page.feature_card_gradients.${feature.gradientIndex}',
        );
        final featureCardGradient = gradient.length >= 2
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null;
        final featureCardBackground = gradient.isEmpty
            ? _themeColor('landing_page.feature_card_background')
            : null;

        Widget buildFeatureCard() {
          return SonalyzeSurface(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.all(isWide ? 36 : 28),
            backgroundColor: featureCardBackground,
            gradient: featureCardGradient,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _themeColor(
                      'landing_page.feature_card_icon_background',
                    ).withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    feature.icon,
                    size: isWide ? 40 : 34,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _tr(feature.titleKey),
                  style: textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _tr(feature.descriptionKey),
                  style: textTheme.bodyLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.88),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tr(feature.metricValueKey),
                        style: textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _tr(feature.metricLabelKey),
                        style: textTheme.labelLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SonalyzeSurface(
          padding: EdgeInsets.zero,
          backgroundColor: cardBackground,
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(isWide ? 48 : 28),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: buildCopy()),
                          const SizedBox(width: 32),
                          Expanded(flex: 5, child: buildFeatureCard()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildCopy(),
                          const SizedBox(height: 28),
                          buildFeatureCard(),
                        ],
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    size: 28,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const SettingsDialog(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureShowcase extends StatelessWidget {
  const _FeatureShowcase({required this.isWide, required this.isMedium});

  final bool isWide;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardBackground = _themeColor('landing_page.feature_card_background');
    final indicatorColor = _themeColor(
      'landing_page.feature_card_selected_border',
    );
    final iconBackground = _themeColor(
      'landing_page.feature_card_icon_background',
    );

    return BlocBuilder<LandingPageBloc, LandingPageState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr('landing_page.metrics.title'),
              style: textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 24.0;
                final features = state.features;
                final maxWidth = constraints.maxWidth;
                final targetWidth = isWide
                    ? 360.0
                    : isMedium
                    ? 320.0
                    : maxWidth;
                final rawColumns = ((maxWidth + gap) / (targetWidth + gap))
                    .floor();
                final columns = math.max(
                  1,
                  math.min(features.length, rawColumns),
                );
                final itemWidth = columns > 0
                    ? (maxWidth - gap * (columns - 1)) / columns
                    : maxWidth;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: features.map((feature) {
                    final index = state.features.indexOf(feature);
                    final isSelected = index == state.activeFeatureIndex;
                    final gradient = _themeColors(
                      'landing_page.feature_card_gradients.${feature.gradientIndex}',
                    );

                    return SizedBox(
                      width: itemWidth,
                      child: GestureDetector(
                        onTap: () => context.read<LandingPageBloc>().add(
                          LandingPageFeatureSelected(index),
                        ),
                        child: SonalyzeSurface(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          constraints: const BoxConstraints(minHeight: 220),
                          padding: const EdgeInsets.all(24),
                          backgroundColor: cardBackground.withValues(
                            alpha: isSelected ? 1.0 : 0.9,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          borderColor: isSelected
                              ? null
                              : indicatorColor.withValues(alpha: 0.22),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ]
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: iconBackground.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  feature.icon,
                                  size: 28,
                                  color: gradient.isNotEmpty
                                      ? gradient.last
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _tr(feature.titleKey),
                                style: textTheme.titleMedium?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _tr(feature.descriptionKey),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: gradient.isNotEmpty
                                      ? gradient.first.withValues(alpha: 0.15)
                                      : indicatorColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _tr(feature.metricValueKey),
                                      style: textTheme.titleMedium?.copyWith(
                                        color: gradient.isNotEmpty
                                            ? gradient.first
                                            : indicatorColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _tr(feature.metricLabelKey),
                                      style: textTheme.labelLarge?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardBackground = _themeColor('landing_page.workflow_card_background');
    final timelineColor = _themeColor('landing_page.workflow_timeline_color');

    return BlocBuilder<LandingPageBloc, LandingPageState>(
      buildWhen: (previous, current) =>
          previous.workflowSteps != current.workflowSteps,
      builder: (context, state) {
        return SonalyzeSurface(
          padding: EdgeInsets.all(isWide ? 40 : 28),
          backgroundColor: cardBackground.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('landing_page.workflow.title'),
                style: textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              ...state.workflowSteps.map(
                (step) =>
                    _WorkflowTile(step: step, timelineColor: timelineColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  const _WorkflowTile({required this.step, required this.timelineColor});

  final LandingPageWorkflowStep step;
  final Color timelineColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLast = step.index == 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: timelineColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  (step.index + 1).toString(),
                  style: textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 64,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        timelineColor,
                        timelineColor.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(step.titleKey),
                  style: textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(step.descriptionKey),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.76),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    final cardBackground = _themeColor('landing_page.contact_card_background');
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<LandingPageBloc, LandingPageState>(
      buildWhen: (previous, current) =>
          previous.submissionStatus != current.submissionStatus,
      builder: (context, state) {
        final status = state.submissionStatus;
        final surfaceColor = cardBackground.withValues(alpha: 0.94);

        return SonalyzeSurface(
          padding: const EdgeInsets.all(32),
          backgroundColor: surfaceColor,
          borderRadius: BorderRadius.circular(32),
          child: status == LandingPageSubmissionStatus.success
              ? _ContactSuccessCard(
                  onReset: () {
                    context.read<LandingPageBloc>().add(
                      const LandingPageContactReset(),
                    );
                  },
                )
              : _ContactForm(status: status, textTheme: textTheme),
        );
      },
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({required this.status, required this.textTheme});

  final LandingPageSubmissionStatus status;
  final TextTheme textTheme;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBackground = _themeColor(
      'landing_page.contact_input_background',
    );
    final inputBorder = _themeColor('landing_page.contact_input_border');
    final buttonBackground = _themeColor(
      'landing_page.contact_button_background',
    );
    final buttonText = _themeColor('landing_page.contact_button_text');
    final subtitleColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.8);

    InputDecoration buildDecoration(String label) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: inputBackground.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: inputBorder.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: inputBorder.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inputBorder, width: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('landing_page.contact.title'),
          style: widget.textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _tr('landing_page.contact.subtitle'),
          style: widget.textTheme.bodyMedium?.copyWith(
            color: subtitleColor,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: buildDecoration(_tr('landing_page.contact.email_label')),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _messageController,
          minLines: 4,
          maxLines: 6,
          decoration: buildDecoration(
            _tr('landing_page.contact.message_label'),
          ),
        ),
        const SizedBox(height: 24),
        SonalyzeButton(
          onPressed: widget.status == LandingPageSubmissionStatus.submitting
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  context.read<LandingPageBloc>().add(
                    LandingPageContactSubmitted(
                      email: _emailController.text.trim(),
                      message: _messageController.text.trim(),
                    ),
                  );
                },
          backgroundColor: buttonBackground,
          foregroundColor: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          borderRadius: BorderRadius.circular(18),
          child: widget.status == LandingPageSubmissionStatus.submitting
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonText),
                  ),
                )
              : Text(
                  _tr('landing_page.contact.submit'),
                  style: widget.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ContactSuccessCard extends StatelessWidget {
  const _ContactSuccessCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final buttonBackground = _themeColor(
      'landing_page.hero_primary_button_background',
    );
    final buttonText = _themeColor('landing_page.hero_primary_button_text');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('landing_page.contact.success'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        SonalyzeButton(
          onPressed: onReset,
          backgroundColor: buttonBackground,
          foregroundColor: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          borderRadius: BorderRadius.circular(16),
          child: Text(
            _tr('landing_page.hero.primary_cta'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    final cardBackground = _themeColor('landing_page.faq_item_background');
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<LandingPageBloc, LandingPageState>(
      builder: (context, state) {
        final tileBackground = cardBackground.withValues(alpha: 0.92);
        final iconColor = Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.7);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr('landing_page.faq.title'),
              style: textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            ...state.faqItems.map((item) {
              final isExpanded = state.expandedFaqs.contains(item.index);
              return SonalyzeAccordionTile(
                title: _tr(item.questionKey),
                body: _tr(item.answerKey),
                isExpanded: isExpanded,
                onToggle: () => context.read<LandingPageBloc>().add(
                  LandingPageFaqToggled(item.index),
                ),
                backgroundColor: tileBackground,
                iconColor: iconColor,
                titleStyle: textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                bodyStyle: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.6,
                ),
                duration: const Duration(milliseconds: 240),
              );
            }),
          ],
        );
      },
    );
  }
}

class _LandingScrollBehavior extends ScrollBehavior {
  const _LandingScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

String _tr(String keyPath) {
  final value = AppConstants.translation(keyPath);
  if (value is String) {
    return value;
  }
  return '';
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  final colors = AppConstants.getThemeColors(keyPath);
  return colors.isNotEmpty ? colors : <Color>[];
}
