import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';

import '../bloc/simulation_page_bloc.dart';

class SimulationResultsChart extends StatefulWidget {
  const SimulationResultsChart({
    super.key,
    required this.result,
    required this.referenceProfiles,
    required this.referenceStatus,
    this.referenceError,
  });

  final SimulationResult result;
  final List<SimulationReferenceProfile> referenceProfiles;
  final SimulationReferenceProfilesStatus referenceStatus;
  final String? referenceError;

  @override
  State<SimulationResultsChart> createState() => _SimulationResultsChartState();
}

class _SimulationResultsChartState extends State<SimulationResultsChart> {
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = _initialProfileId(widget.referenceProfiles);
  }

  @override
  void didUpdateWidget(covariant SimulationResultsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasSelectedProfile(widget.referenceProfiles, _selectedProfileId)) {
      _selectedProfileId = _initialProfileId(widget.referenceProfiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final selectedProfile = _selectedProfile;
    final metricEntries = selectedProfile == null
        ? const <_MetricChartEntry>[]
        : _buildMetricEntries(selectedProfile);
    final hasReferenceMetrics = metricEntries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                _tr(
                  'simulation_page.room_type_selector.label',
                  fallback: 'Reference profile',
                ),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildReferenceSelector(context, selectedProfile),
                ),
              ),
            ],
          ),
        ),
        if (selectedProfile?.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            selectedProfile!.notes!,
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (!hasReferenceMetrics)
          _buildReferencePlaceholder(context)
        else ...[
          SizedBox(
            height: 320,
            child: _buildChart(
              context,
              entries: metricEntries,
              measuredColor: colorScheme.primary,
              referenceColor: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(
            context,
            measuredColor: colorScheme.primary,
            referenceColor: colorScheme.secondary,
          ),
        ],
      ],
    );
  }

  Widget _buildReferenceSelector(
    BuildContext context,
    SimulationReferenceProfile? selectedProfile,
  ) {
    final textTheme = Theme.of(context).textTheme;

    switch (widget.referenceStatus) {
      case SimulationReferenceProfilesStatus.loading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _tr(
                'simulation_page.reference_profiles.loading',
                fallback: 'Loading profiles…',
              ),
              style: textTheme.bodyMedium,
            ),
          ],
        );
      case SimulationReferenceProfilesStatus.failure:
        return Text(
          widget.referenceError ??
              _tr(
                'simulation_page.reference_profiles.error',
                fallback: 'Failed to load profiles',
              ),
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        );
      case SimulationReferenceProfilesStatus.initial:
      case SimulationReferenceProfilesStatus.success:
        break;
    }

    if (widget.referenceProfiles.isEmpty) {
      return Text(
        _tr(
          'simulation_page.reference_profiles.empty',
          fallback: 'No reference profiles available',
        ),
        style: textTheme.bodyMedium,
      );
    }

    return DropdownButton<String>(
      value: selectedProfile?.id ?? widget.referenceProfiles.first.id,
      items: widget.referenceProfiles
          .map(
            (profile) => DropdownMenuItem(
              value: profile.id,
              child: Text(profile.displayName, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _selectedProfileId = value);
      },
    );
  }

  Widget _buildReferencePlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final isFailure =
        widget.referenceStatus == SimulationReferenceProfilesStatus.failure;
    final message = isFailure
        ? widget.referenceError ??
              _tr(
                'simulation_page.results.reference_unavailable',
                fallback:
                    'Reference profiles are unavailable. Try again later.',
              )
        : _tr(
            'simulation_page.results.reference_select_prompt',
            fallback:
                'Select a reference profile to compare your measurements.',
          );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required List<_MetricChartEntry> entries,
    required Color measuredColor,
    required Color referenceColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: 1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = entries[groupIndex];
              final isMeasuredRod = rodIndex == 0;
              final value = isMeasuredRod
                  ? entry.measuredValue
                  : entry.idealValue;
              final unit = entry.unit != null && entry.unit!.isNotEmpty
                  ? ' ${entry.unit}'
                  : '';
              final label = isMeasuredRod
                  ? _tr(
                      'simulation_page.results.measured',
                      fallback: 'Measured value',
                    )
                  : _tr(
                      'simulation_page.results.ideal',
                      fallback: 'Reference value',
                    );
              final displayValue = value == null
                  ? '-'
                  : '${value.toStringAsFixed(2)}$unit';
              return BarTooltipItem(
                '${entry.title}\n$label: $displayValue',
                textTheme.bodySmall ?? const TextStyle(fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                '${(value * 100).round()}%',
                style: textTheme.labelSmall?.copyWith(color: Colors.white70),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entries[index].title,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.15),
            strokeWidth: 1,
            dashArray: value == 0 || value == 1 ? null : const [4, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.2)),
            bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
        ),
        barGroups: List.generate(entries.length, (index) {
          final entry = entries[index];
          return BarChartGroupData(
            x: index,
            barsSpace: 6,
            barRods: [
              BarChartRodData(
                toY: entry.hasMeasurement ? entry.normalizedMeasured : 0,
                gradient: LinearGradient(
                  colors: entry.hasMeasurement
                      ? [measuredColor, measuredColor.withOpacity(0.7)]
                      : [
                          measuredColor.withOpacity(0.3),
                          measuredColor.withOpacity(0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              BarChartRodData(
                toY: entry.normalizedIdeal,
                gradient: LinearGradient(
                  colors: [referenceColor, referenceColor.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context, {
    required Color measuredColor,
    required Color referenceColor,
  }) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _LegendItem(
          color: measuredColor,
          label: _tr(
            'simulation_page.results.legend_measured',
            fallback: 'Measured value',
          ),
          style: bodyStyle,
        ),
        _LegendItem(
          color: referenceColor,
          label: _tr(
            'simulation_page.results.legend_ideal',
            fallback: 'Reference value (simulation)',
          ),
          style: bodyStyle,
        ),
      ],
    );
  }

  List<_MetricChartEntry> _buildMetricEntries(
    SimulationReferenceProfile profile,
  ) {
    final averages = _averageMetrics(widget.result);
    return profile.metrics
        .map((metric) {
          final double? measured = averages[metric.key];
          final hasMeasurement = measured != null;
          final comparisonValue = measured ?? metric.value;
          final bounds = _resolveRange(metric, comparisonValue);

          return _MetricChartEntry(
            title: metric.label,
            unit: metric.unit,
            measuredValue: measured,
            idealValue: metric.value,
            normalizedMeasured: measured == null
                ? 0
                : _normalize(measured, bounds.start, bounds.end),
            normalizedIdeal: _normalize(metric.value, bounds.start, bounds.end),
            hasMeasurement: hasMeasurement,
          );
        })
        .toList(growable: false);
  }

  Map<String, double> _averageMetrics(SimulationResult result) {
    final aggregates = <String, _MetricAccumulator>{};
    for (final pair in result.pairs) {
      pair.metrics.values.forEach((key, value) {
        final metricValue = value;
        if (metricValue == null || metricValue.isNaN) {
          return;
        }
        aggregates
            .putIfAbsent(key, () => _MetricAccumulator())
            .add(metricValue);
      });
    }
    return aggregates.map(
      (key, accumulator) => MapEntry(key, accumulator.average),
    );
  }

  RangeValues _resolveRange(
    SimulationReferenceMetric metric,
    double comparisonValue,
  ) {
    double? min = metric.minValue;
    double? max = metric.maxValue;

    if (min != null && max != null && max > min) {
      return RangeValues(min, max);
    }

    final magnitude = math
        .max(metric.value.abs(), comparisonValue.abs())
        .clamp(0.5, 100.0);
    const paddingFactor = 0.5;

    min ??= math.min(metric.value, comparisonValue) - magnitude * paddingFactor;
    max ??= math.max(metric.value, comparisonValue) + magnitude * paddingFactor;

    if (max - min < 1e-6) {
      max = min + 1;
    }

    return RangeValues(min, max);
  }

  double _normalize(double value, double min, double max) {
    if (max - min <= 0) {
      return 0;
    }
    final normalized = (value - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }

  String? _initialProfileId(List<SimulationReferenceProfile> profiles) {
    if (profiles.isEmpty) {
      return null;
    }
    return profiles.first.id;
  }

  bool _hasSelectedProfile(
    List<SimulationReferenceProfile> profiles,
    String? id,
  ) {
    if (id == null) {
      return false;
    }
    for (final profile in profiles) {
      if (profile.id == id) {
        return true;
      }
    }
    return false;
  }

  SimulationReferenceProfile? get _selectedProfile {
    final id = _selectedProfileId;
    if (id == null) {
      return null;
    }
    for (final profile in widget.referenceProfiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }
}

class _MetricChartEntry {
  const _MetricChartEntry({
    required this.title,
    required this.unit,
    required this.measuredValue,
    required this.idealValue,
    required this.normalizedMeasured,
    required this.normalizedIdeal,
    required this.hasMeasurement,
  });

  final String title;
  final String? unit;
  final double? measuredValue;
  final double idealValue;
  final double normalizedMeasured;
  final double normalizedIdeal;
  final bool hasMeasurement;
}

class _MetricAccumulator {
  double _sum = 0;
  int _count = 0;

  void add(double value) {
    _sum += value;
    _count += 1;
  }

  double get average => _count == 0 ? 0 : _sum / _count;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.style});

  final Color color;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
  }
}

String _tr(String keyPath, {String? fallback}) {
  final value = AppConstants.translation(keyPath);
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return keyPath;
}
