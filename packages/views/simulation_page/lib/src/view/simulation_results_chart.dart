import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';

import '../bloc/simulation_page_bloc.dart';

enum RoomType { classroom, concertHall, homeTheater, recordingStudio, office }

class RoomAcousticProfile {
  final double rt60;
  final double edt;
  final double d50;
  final double c50;
  final double c80;
  final double drr;

  const RoomAcousticProfile({
    required this.rt60,
    required this.edt,
    required this.d50,
    required this.c50,
    required this.c80,
    required this.drr,
  });
}

class SimulationResultsChart extends StatefulWidget {
  final SimulationResult result;

  const SimulationResultsChart({super.key, required this.result});

  @override
  State<SimulationResultsChart> createState() => _SimulationResultsChartState();
}

class _SimulationResultsChartState extends State<SimulationResultsChart> {
  RoomType _selectedRoomType = RoomType.classroom;

  static const Map<RoomType, RoomAcousticProfile> _idealProfiles = {
    RoomType.classroom: RoomAcousticProfile(
      rt60: 0.6,
      edt: 0.6,
      d50: 0.6,
      c50: 2.0,
      c80: 4.0,
      drr: 0.0,
    ),
    RoomType.concertHall: RoomAcousticProfile(
      rt60: 2.0,
      edt: 2.0,
      d50: 0.3,
      c50: -2.0,
      c80: -1.0,
      drr: -5.0,
    ),
    RoomType.homeTheater: RoomAcousticProfile(
      rt60: 0.4,
      edt: 0.4,
      d50: 0.7,
      c50: 5.0,
      c80: 8.0,
      drr: 5.0,
    ),
    RoomType.recordingStudio: RoomAcousticProfile(
      rt60: 0.3,
      edt: 0.3,
      d50: 0.8,
      c50: 10.0,
      c80: 15.0,
      drr: 10.0,
    ),
    RoomType.office: RoomAcousticProfile(
      rt60: 0.5,
      edt: 0.5,
      d50: 0.6,
      c50: 3.0,
      c80: 6.0,
      drr: 2.0,
    ),
  };

  // Normalization ranges
  static const double _maxRt60 = 3.0;
  static const double _maxEdt = 3.0;
  static const double _maxD50 = 1.0;
  static const double _minC50 = -10.0;
  static const double _maxC50 = 20.0;
  static const double _minC80 = -10.0;
  static const double _maxC80 = 20.0;
  static const double _minDrr = -20.0;
  static const double _maxDrr = 20.0;

  double _normalize(double value, double min, double max) {
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  String _tr(String key) {
    final value = AppConstants.translation(key);
    return value is String ? value : key;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final idealProfile = _idealProfiles[_selectedRoomType]!;

    // Average the measured values across all pairs for the chart
    // Or should we show one chart per pair? The user said "All of the measured values should be displayed".
    // Usually, we average them or show the first one if it's a single point simulation.
    // Let's average them for the chart overview.

    double avgRt60 = 0;
    double avgEdt = 0;
    double avgD50 = 0;
    double avgC50 = 0;
    double avgC80 = 0;
    double avgDrr = 0;

    if (widget.result.pairs.isNotEmpty) {
      for (final pair in widget.result.pairs) {
        avgRt60 += pair.metrics.rt60Seconds ?? 0.0;
        avgEdt += pair.metrics.edtSeconds ?? 0.0;
        avgD50 += pair.metrics.earlyDecay50 ?? 0.0;
        avgC50 += pair.metrics.clarity50Db ?? 0.0;
        avgC80 += pair.metrics.clarity80Db ?? 0.0;
        avgDrr += pair.metrics.directToReverberantDb ?? 0.0;
      }
      final count = widget.result.pairs.length;
      avgRt60 /= count;
      avgEdt /= count;
      avgD50 /= count;
      avgC50 /= count;
      avgC80 /= count;
      avgDrr /= count;
    }

    final titles = ['RT60', 'EDT', 'D50', 'C50', 'C80', 'DRR'];
    final measuredValues = [avgRt60, avgEdt, avgD50, avgC50, avgC80, avgDrr];
    final idealValues = [
      idealProfile.rt60,
      idealProfile.edt,
      idealProfile.d50,
      idealProfile.c50,
      idealProfile.c80,
      idealProfile.drr,
    ];
    final normalizedMeasured = [
      _normalize(avgRt60, 0, _maxRt60),
      _normalize(avgEdt, 0, _maxEdt),
      _normalize(avgD50, 0, _maxD50),
      _normalize(avgC50, _minC50, _maxC50),
      _normalize(avgC80, _minC80, _maxC80),
      _normalize(avgDrr, _minDrr, _maxDrr),
    ];
    final normalizedIdeal = [
      _normalize(idealProfile.rt60, 0, _maxRt60),
      _normalize(idealProfile.edt, 0, _maxEdt),
      _normalize(idealProfile.d50, 0, _maxD50),
      _normalize(idealProfile.c50, _minC50, _maxC50),
      _normalize(idealProfile.c80, _minC80, _maxC80),
      _normalize(idealProfile.drr, _minDrr, _maxDrr),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room Type Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _tr('simulation_page.room_type_selector.label'),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<RoomType>(
                value: _selectedRoomType,
                underline: const SizedBox(),
                items: RoomType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_tr('simulation_page.room_type.${type.name}')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRoomType = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Bar Chart
        SizedBox(
          height: 300,
          child: RotatedBox(
            quarterTurns: 1,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.2, // Leave space for tooltips/labels if needed
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    rotateAngle: -90,
                    getTooltipColor: (group) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final metricName = titles[groupIndex];
                      final isMeasured = rodIndex == 0;
                      final value = isMeasured
                          ? measuredValues[groupIndex]
                          : idealValues[groupIndex];
                      final label = isMeasured
                          ? _tr('simulation_page.legend.measured')
                          : _tr('simulation_page.legend.ideal');
                      return BarTooltipItem(
                        '$metricName\n$label: ${value.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Text(
                                titles[index],
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(titles.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: normalizedMeasured[index],
                        color: Colors.blue,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: normalizedIdeal[index],
                        color: Colors.green.withValues(alpha: 0.5),
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(
              color: Colors.blue,
              label: _tr('simulation_page.legend.measured'),
            ),
            const SizedBox(width: 24),
            _LegendItem(
              color: Colors.green.withValues(alpha: 0.5),
              label: _tr('simulation_page.legend.ideal'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
