import 'package:common_helpers/common_helpers.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:room_modeling/room_modeling.dart';

import '../bloc/simulation_page_bloc.dart';

class SimulationPageScreen extends StatelessWidget {
  const SimulationPageScreen({super.key});

  static const String routeName = '/simulation';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SimulationPageBloc()),
        BlocProvider(create: (_) => RoomModelingBloc()),
      ],
      child: const _SimulationPageView(),
    );
  }
}

class _SimulationPageView extends StatelessWidget {
  const _SimulationPageView();

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = _themeColors(
      'simulation_page.background_gradient',
    );

    return BlocListener<SimulationPageBloc, SimulationPageState>(
      listenWhen: (previous, current) =>
          previous.activeStepIndex != current.activeStepIndex,
      listener: (context, state) {
        // Sync room modeling step with simulation step
        final roomBloc = context.read<RoomModelingBloc>();
        if (state.activeStepIndex == 0) {
          // Step 1: Construct wall structure
          roomBloc.add(const StepChanged(RoomModelingStep.structure));
        } else if (state.activeStepIndex >= 1) {
          // Step 2+: Furnishing
          roomBloc.add(const StepChanged(RoomModelingStep.furnishing));
        }
      },
      child: Scaffold(
        backgroundColor: _themeColor('app.background'),
        body: Container(
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
                final isWide = constraints.maxWidth >= 1280;
                final isMedium = constraints.maxWidth >= 980;
                final contentPadding = EdgeInsets.symmetric(
                  horizontal: isWide
                      ? 96
                      : isMedium
                      ? 64
                      : 24,
                  vertical: isWide ? 48 : 32,
                );

                return ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: WidgetStateProperty.all<Color>(
                      _themeColor(
                        'simulation_page.scrollbar_thumb',
                      ).withValues(alpha: 0.75),
                    ),
                    thickness: const WidgetStatePropertyAll<double>(6),
                    radius: const Radius.circular(999),
                  ),
                  child: SingleChildScrollView(
                    padding: contentPadding,
                    child: BlocBuilder<SimulationPageBloc, SimulationPageState>(
                      buildWhen: (previous, current) =>
                          previous.activeStepIndex != current.activeStepIndex,
                      builder: (context, simulationState) {
                        // Hide tools panel in steps 3+ (simulation and results)
                        final hideToolsPanel =
                            simulationState.activeStepIndex >= 2;
                        // Only show metrics in step 4 (results)
                        final showMetrics =
                            simulationState.activeStepIndex == 3;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SimulationHeader(),
                            SizedBox(height: isWide ? 40 : 32),
                            SizedBox(
                              height: 600,
                              child: RoomModelingWidget(
                                bloc: context.read<RoomModelingBloc>(),
                                hideToolsPanel: hideToolsPanel,
                              ),
                            ),
                            SizedBox(height: isWide ? 32 : 24),
                            const _SimulationTimelineCard(),
                            if (showMetrics) ...[
                              SizedBox(height: isWide ? 48 : 36),
                              const _SimulationMetricSection(),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationHeader extends StatelessWidget {
  const _SimulationHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeColor = _themeColor('simulation_page.header_badge_background');
    final badgeText = _themeColor('simulation_page.header_badge_text');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _tr('simulation_page.badge'),
            style: textTheme.labelLarge?.copyWith(
              color: badgeText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _tr('simulation_page.title'),
          style: textTheme.displaySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _tr('simulation_page.subtitle'),
          style: textTheme.titleMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.78),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _SimulationMetricSection extends StatelessWidget {
  const _SimulationMetricSection();

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.metrics_background');

    return BlocBuilder<SimulationPageBloc, SimulationPageState>(
      builder: (context, state) {
        return SonalyzeSurface(
          padding: const EdgeInsets.all(28),
          backgroundColor: panelColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('simulation_page.results.title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 1000;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - 32) / 3
                      : double.infinity;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final series in state.metrics)
                        SizedBox(
                          width: itemWidth,
                          child: _MetricChartCard(series: series),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricChartCard extends StatelessWidget {
  const _MetricChartCard({required this.series});

  final SimulationMetricSeries series;

  @override
  Widget build(BuildContext context) {
    final cardColor = _themeColor('simulation_page.graphs.card_background');
    final axisColor = _themeColor('simulation_page.graphs.axis');
    final lineColor = _themeColor(series.colorKey);
    final fillColor = _themeColor('${series.colorKey}_fill');

    final latestValue = series.values.last;

    return SonalyzeSurface(
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(series.labelKey),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${formatNumber(latestValue, fractionDigits: 2)} ${_tr(series.unitKey)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _MetricChartPainter(
                series: series,
                axisColor: axisColor.withValues(alpha: 0.4),
                lineColor: lineColor,
                fillColor: fillColor.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({
    required this.series,
    required this.axisColor,
    required this.lineColor,
    required this.fillColor,
  });

  final SimulationMetricSeries series;
  final Color axisColor;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final origin = Offset(padding, size.height - padding);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas.drawLine(
      origin,
      Offset(origin.dx + chartWidth, origin.dy),
      axisPaint,
    );
    canvas.drawLine(
      origin,
      Offset(origin.dx, origin.dy - chartHeight),
      axisPaint,
    );

    final maxValue = series.values.reduce((a, b) => a > b ? a : b);
    final minValue = series.values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs() < 0.001
        ? 1
        : (maxValue - minValue);

    final points = <Offset>[];
    for (var i = 0; i < series.values.length; i++) {
      final progress = i / (series.values.length - 1);
      final x = origin.dx + chartWidth * progress;
      final normalized = (series.values[i] - minValue) / span;
      final y = origin.dy - normalized * chartHeight;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, origin.dy);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, origin.dy);
    fillPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _SimulationTimelineCard extends StatelessWidget {
  const _SimulationTimelineCard();

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.metrics_background');
    final activeColor = _themeColor('simulation_page.timeline_active');
    final inactiveColor = _themeColor('simulation_page.timeline_inactive');
    final onPrimary = _themeColor('app.on_primary');
    final warningColor = _themeColor('simulation_page.timeline_inactive');

    return BlocBuilder<SimulationPageBloc, SimulationPageState>(
      builder: (context, simulationState) {
        return BlocBuilder<RoomModelingBloc, RoomModelingState>(
          builder: (context, roomState) {
            // Can only advance from step 0 to step 1 if room is closed
            final canAdvance =
                simulationState.steps.isNotEmpty &&
                (simulationState.activeStepIndex > 0 || roomState.isRoomClosed);

            return SonalyzeSurface(
              padding: const EdgeInsets.all(28),
              backgroundColor: panelColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tr('simulation_page.timeline.title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SonalyzeButton(
                            onPressed: simulationState.activeStepIndex > 0
                                ? () => context.read<SimulationPageBloc>().add(
                                    const SimulationTimelineStepBack(),
                                  )
                                : null,
                            backgroundColor: inactiveColor,
                            foregroundColor: onPrimary,
                            borderRadius: BorderRadius.circular(18),
                            icon: const Icon(Icons.fast_rewind_outlined),
                            child: Text(_tr('simulation_page.timeline.back')),
                          ),
                          const SizedBox(width: 12),
                          SonalyzeButton(
                            onPressed: canAdvance
                                ? () => context.read<SimulationPageBloc>().add(
                                    const SimulationTimelineAdvanced(),
                                  )
                                : null,
                            backgroundColor: activeColor,
                            foregroundColor: onPrimary,
                            borderRadius: BorderRadius.circular(18),
                            icon: const Icon(Icons.fast_forward_outlined),
                            child: Text(
                              _tr('simulation_page.timeline.advance'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (simulationState.activeStepIndex == 0 &&
                      !roomState.isRoomClosed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        _tr('simulation_page.timeline.close_room_hint'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: warningColor),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      for (var i = 0; i < simulationState.steps.length; i++)
                        _SimulationTimelineStepTile(
                          descriptor: simulationState.steps[i],
                          isActive: simulationState.activeStepIndex == i,
                          isComplete: i < simulationState.activeStepIndex,
                          isLast: i == simulationState.steps.length - 1,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SimulationTimelineStepTile extends StatelessWidget {
  const _SimulationTimelineStepTile({
    required this.descriptor,
    required this.isActive,
    required this.isComplete,
    required this.isLast,
    required this.activeColor,
    required this.inactiveColor,
  });

  final SimulationStepDescriptor descriptor;
  final bool isActive;
  final bool isComplete;
  final bool isLast;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final descriptionStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      height: 1.5,
    );

    final indicatorColor = isActive
        ? activeColor
        : isComplete
        ? activeColor.withValues(alpha: 0.5)
        : inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: indicatorColor.withValues(
                    alpha: isActive ? 0.25 : 0.18,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: indicatorColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${descriptor.index + 1}',
                    style: textTheme.labelLarge?.copyWith(
                      color: indicatorColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: indicatorColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr(descriptor.titleKey), style: titleStyle),
                const SizedBox(height: 6),
                Text(_tr(descriptor.descriptionKey), style: descriptionStyle),
              ],
            ),
          ),
        ],
      ),
    );
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
  return AppConstants.getThemeColors(keyPath);
}
