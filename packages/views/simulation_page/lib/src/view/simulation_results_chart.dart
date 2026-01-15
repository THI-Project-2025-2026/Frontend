import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';

import '../bloc/simulation_page_bloc.dart';

const Color _measuredBarColor = Color(0xFF3B82F6);
const Color _idealBarColor = Color(0xFF22C55E);
const Color _raytracingBarColor = Color(0xFFEF4444);

class SimulationResultsChart extends StatefulWidget {
  const SimulationResultsChart({
    super.key,
    required this.result,
    this.raytracingResult,
    required this.referenceProfiles,
    required this.referenceStatus,
    this.referenceError,
  });

  final SimulationResult result;
  final SimulationResult? raytracingResult;
  final List<SimulationReferenceProfile> referenceProfiles;
  final SimulationReferenceProfilesStatus referenceStatus;
  final String? referenceError;

  @override
  State<SimulationResultsChart> createState() => _SimulationResultsChartState();
}

class _SimulationResultsChartState extends State<SimulationResultsChart>
    with TickerProviderStateMixin {
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
    const measuredColor = _measuredBarColor;
    const referenceColor = _idealBarColor;
    const raytracingColor = _raytracingBarColor;

    final selectedProfile = _selectedProfile;
    final metricEntries = selectedProfile == null
        ? const <_MetricChartEntry>[]
        : _buildMetricEntries(selectedProfile);
    final hasReferenceMetrics = metricEntries.isNotEmpty;
    final hasRaytracingResult = widget.raytracingResult != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface.withValues(alpha: 0.95),
                colorScheme.surfaceVariant.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
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
            _translateProfileNotes(selectedProfile!.id, selectedProfile.notes),
            style: textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (!hasReferenceMetrics)
          _buildReferencePlaceholder(context)
        else ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _buildMetricCard(
              context,
              entries: metricEntries,
              measuredColor: measuredColor,
              referenceColor: referenceColor,
              raytracingColor: raytracingColor,
              showRaytracing: hasRaytracingResult,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(
            context,
            measuredColor: measuredColor,
            referenceColor: referenceColor,
            raytracingColor: raytracingColor,
            showRaytracing: hasRaytracingResult,
          ),
        ],
      ],
    );
  }

  Widget _buildReferenceSelector(
    BuildContext context,
    SimulationReferenceProfile? selectedProfile,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

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

    final selectedId = selectedProfile?.id ?? widget.referenceProfiles.first.id;

    return DropdownButtonFormField<String>(
      value: selectedId,
      isExpanded: true,
      dropdownColor: colorScheme.surface,
      icon: Icon(
        Icons.expand_more,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.layers_outlined, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.surface.withValues(alpha: 0.95),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.8)),
        ),
      ),
      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      items: widget.referenceProfiles
          .map(
            (profile) => DropdownMenuItem(
              value: profile.id,
              child: Text(_translateProfileName(profile.id, profile.displayName), overflow: TextOverflow.ellipsis),
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

  Widget _buildMetricCard(
    BuildContext context, {
    required List<_MetricChartEntry> entries,
    required Color measuredColor,
    required Color referenceColor,
    required Color raytracingColor,
    required bool showRaytracing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 35,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == entries.length - 1 ? 0 : 24,
            ),
            child: _MetricComparisonRow(
              entry: entry,
              measuredColor: measuredColor,
              idealColor: referenceColor,
              raytracingColor: raytracingColor,
              showRaytracing: showRaytracing,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context, {
    required Color measuredColor,
    required Color referenceColor,
    required Color raytracingColor,
    required bool showRaytracing,
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
        if (showRaytracing)
          _LegendItem(
            color: raytracingColor,
            label: _tr(
              'simulation_page.results.legend_raytracing',
              fallback: 'Raytracing simulation',
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
    final raytracingAverages = widget.raytracingResult != null
        ? _averageMetrics(widget.raytracingResult!)
        : <String, double>{};
    // Merge metrics from profile with any metrics present in results
    final Map<String, SimulationReferenceMetric> merged = {
      for (final m in profile.metrics) m.key: m,
    };

    final allKeys = <String>{
      ...merged.keys,
      ...averages.keys,
      ...raytracingAverages.keys,
    };

    return allKeys.map((key) {
      final metric = merged[key] ?? SimulationReferenceMetric(
        key: key,
        label: key,
        value: averages[key] ?? raytracingAverages[key] ?? 0,
      );

      final double? measured = averages[key];
      final double? raytracing = raytracingAverages[key];
      final hasMeasurement = measured != null;
      final hasRaytracing = raytracing != null;

      // Include raytracing value when computing bounds
      final allValues = [metric.value];
      if (measured != null) allValues.add(measured);
      if (raytracing != null) allValues.add(raytracing);
      final bounds = _resolveRangeWithValues(metric, allValues);

      return _MetricChartEntry(
        title: metric.label,
        unit: metric.unit,
        measuredValue: measured,
        idealValue: metric.value,
        raytracingValue: raytracing,
        normalizedMeasured: measured == null
            ? 0
            : _normalize(measured, bounds.start, bounds.end),
        normalizedIdeal: _normalize(metric.value, bounds.start, bounds.end),
        normalizedRaytracing: raytracing == null
            ? 0
            : _normalize(raytracing, bounds.start, bounds.end),
        hasMeasurement: hasMeasurement,
        hasRaytracing: hasRaytracing,
      );
    }).toList(growable: false);
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

  RangeValues _resolveRangeWithValues(
    SimulationReferenceMetric metric,
    List<double> values,
  ) {
    double? min = metric.minValue;
    double? max = metric.maxValue;

    if (min != null && max != null && max > min) {
      return RangeValues(min, max);
    }

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final magnitude = maxVal.abs().clamp(0.5, 100.0);
    const paddingFactor = 0.5;

    min ??= minVal - magnitude * paddingFactor;
    max ??= maxVal + magnitude * paddingFactor;

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
    required this.raytracingValue,
    required this.normalizedMeasured,
    required this.normalizedIdeal,
    required this.normalizedRaytracing,
    required this.hasMeasurement,
    required this.hasRaytracing,
  });

  final String title;
  final String? unit;
  final double? measuredValue;
  final double idealValue;
  final double? raytracingValue;
  final double normalizedMeasured;
  final double normalizedIdeal;
  final double normalizedRaytracing;
  final bool hasMeasurement;
  final bool hasRaytracing;
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

class _MetricComparisonRow extends StatelessWidget {
  const _MetricComparisonRow({
    required this.entry,
    required this.measuredColor,
    required this.idealColor,
    required this.raytracingColor,
    required this.showRaytracing,
  });

  final _MetricChartEntry entry;
  final Color measuredColor;
  final Color idealColor;
  final Color raytracingColor;
  final bool showRaytracing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final measuredLabel = _tr(
      'simulation_page.results.measured',
      fallback: 'Measured value',
    );
    final idealLabel = _tr(
      'simulation_page.results.ideal',
      fallback: 'Reference value',
    );
    final raytracingLabel = _tr(
      'simulation_page.results.raytracing',
      fallback: 'Raytracing',
    );

    final measuredValueText = entry.measuredValue == null
        ? _tr('simulation_page.results.not_available', fallback: 'N/A')
        : _formatMetricValue(entry.measuredValue!, entry.unit);
    final idealValueText = _formatMetricValue(entry.idealValue, entry.unit);
    final raytracingValueText = entry.raytracingValue == null
        ? _tr('simulation_page.results.not_available', fallback: 'N/A')
        : _formatMetricValue(entry.raytracingValue!, entry.unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _MetricValueChip(
              label: measuredLabel,
              valueText: measuredValueText,
              color: measuredColor,
              dimmed: !entry.hasMeasurement,
            ),
            const SizedBox(width: 8),
            _MetricValueChip(
              label: idealLabel,
              valueText: idealValueText,
              color: idealColor,
            ),
            if (showRaytracing) ...[
              const SizedBox(width: 8),
              _MetricValueChip(
                label: raytracingLabel,
                valueText: raytracingValueText,
                color: raytracingColor,
                dimmed: !entry.hasRaytracing,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _MetricBarTrack(
          progress: entry.normalizedMeasured,
          color: measuredColor,
          isActive: entry.hasMeasurement,
        ),
        const SizedBox(height: 8),
        _MetricBarTrack(
          progress: entry.normalizedIdeal,
          color: idealColor,
          isActive: true,
        ),
        if (showRaytracing) ...[
          const SizedBox(height: 8),
          _MetricBarTrack(
            progress: entry.normalizedRaytracing,
            color: raytracingColor,
            isActive: entry.hasRaytracing,
          ),
        ],
      ],
    );
  }
}

class _MetricValueChip extends StatelessWidget {
  const _MetricValueChip({
    required this.label,
    required this.valueText,
    required this.color,
    this.dimmed = false,
  });

  final String label;
  final String valueText;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = dimmed ? color.withOpacity(0.5) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: effectiveColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label · $valueText',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBarTrack extends StatelessWidget {
  const _MetricBarTrack({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  final double progress;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final clamped = progress.clamp(0.0, 1.0);
        final activeWidth = isActive ? width * clamped : 0.0;
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: activeWidth,
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.white, 0.25)!],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatMetricValue(double value, String? unit) {
  final digits = value.abs() >= 10 ? 1 : 2;
  final formatted = value.toStringAsFixed(digits);
  if (unit == null || unit.isEmpty) {
    return formatted;
  }
  return '$formatted $unit';
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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

String _translateProfileName(String profileId, String displayName) {
  final value = AppConstants.translation('reference_profiles.$profileId.name');
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return displayName;
}

String _translateProfileNotes(String profileId, String? notes) {
  final value = AppConstants.translation('reference_profiles.$profileId.notes');
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return notes ?? '';
}
