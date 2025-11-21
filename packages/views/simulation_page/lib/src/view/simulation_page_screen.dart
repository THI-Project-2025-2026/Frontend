import 'dart:convert';

import 'package:common_helpers/common_helpers.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:room_modeling/room_modeling.dart';
import 'package:sonalyze_webview/sonalyze_webview.dart';

import '../bloc/simulation_page_bloc.dart';

class SimulationPageScreen extends StatelessWidget {
  const SimulationPageScreen({super.key});

  static const String routeName = '/simulation';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SimulationPageBloc(),
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

    return Scaffold(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SimulationHeader(),
                      SizedBox(height: isWide ? 40 : 32),
                      const SizedBox(height: 600, child: RoomModelingWidget()),
                      SizedBox(height: isWide ? 48 : 36),
                      const _SimulationMetricSection(),
                      SizedBox(height: isWide ? 48 : 36),
                      const _RoomCreatorSection(),
                    ],
                  ),
                ),
              );
            },
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
                _tr('simulation_page.metrics.title'),
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

class _RoomCreatorSection extends StatefulWidget {
  const _RoomCreatorSection();

  @override
  State<_RoomCreatorSection> createState() => _RoomCreatorSectionState();
}

class _RoomCreatorSectionState extends State<_RoomCreatorSection> {
  static const _bundlePrefix = 'assets/frontend_roomcreator/';

  late final Future<String> _htmlFuture = _loadInlineBundle();

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.panel_background');
    final title = _translationOrFallback(
      'simulation_page.room_creator.title',
      'Interactive Room Creator',
    );
    final description = _translationOrFallback(
      'simulation_page.room_creator.subtitle',
      'Experiment with a fully interactive layout preview.',
    );

    if (_isLinuxDesktop) {
      return _RoomCreatorNotice(
        title: title,
        description: description,
        message: _translationOrFallback(
          'simulation_page.room_creator.unsupported',
          'This preview is unavailable on Linux builds.',
        ),
        panelColor: panelColor,
        wrapInSurface: true,
      );
    }

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FutureBuilder<String>(
                  future: _htmlFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _RoomCreatorLoading();
                    }
                    if (snapshot.hasError) {
                      return _RoomCreatorNotice(
                        title: title,
                        description: description,
                        message: _translationOrFallback(
                          'simulation_page.room_creator.error',
                          'Unable to load the Room Creator bundle.',
                        ),
                        panelColor: panelColor,
                        wrapInSurface: false,
                      );
                    }
                    final html = snapshot.data ?? '';
                    if (html.isEmpty) {
                      return _RoomCreatorNotice(
                        title: title,
                        description: description,
                        message: _translationOrFallback(
                          'simulation_page.room_creator.empty',
                          'No web content available.',
                        ),
                        panelColor: panelColor,
                        wrapInSurface: false,
                      );
                    }
                    return SonalyzeWebView(
                      htmlContent: html,
                      backgroundColor: Colors.black,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isLinuxDesktop {
    if (kIsWeb) {
      return false;
    }
    final resolved =
        debugDefaultTargetPlatformOverride ?? defaultTargetPlatform;
    return resolved == TargetPlatform.linux;
  }

  Future<String> _loadInlineBundle() async {
    var html = await rootBundle.loadString('${_bundlePrefix}index.html');
    html = await _inlineStyles(html);
    html = await _inlineScripts(html);
    html = await _inlineFavicon(html);
    html = _stripNoscript(html);
    return html;
  }

  Future<String> _inlineStyles(String html) async {
    final regex = RegExp(
      r'<link[^>]*rel=["\"][^>]*stylesheet[^>]*href=["\"]([^"\"]+)["\"][^>]*>',
      caseSensitive: false,
    );
    final matches = regex.allMatches(html).toList();
    for (final match in matches) {
      final tag = match.group(0)!;
      final fileName = match.group(1)!;
      final css = await rootBundle.loadString('$_bundlePrefix$fileName');
      html = html.replaceFirst(tag, '<style>$css</style>');
    }
    return html;
  }

  Future<String> _inlineScripts(String html) async {
    final regex = RegExp(
      r'<script[^>]*src=["\"]([^"\"]+)["\"][^>]*></script>',
      caseSensitive: false,
    );
    final matches = regex.allMatches(html).toList();
    for (final match in matches) {
      final tag = match.group(0)!;
      final fileName = match.group(1)!;
      final js = await rootBundle.loadString('$_bundlePrefix$fileName');
      final typeMatch = RegExp(r'type=["\"]([^"\"]+)["\"]').firstMatch(tag);
      final typeAttr = typeMatch != null ? ' type="${typeMatch.group(1)}"' : '';
      html = html.replaceFirst(tag, '<script$typeAttr>$js</script>');
    }
    return html;
  }

  Future<String> _inlineFavicon(String html) async {
    final regex = RegExp(
      r'<link[^>]*rel=["\"]icon["\"][^>]*href=["\"]([^"\"]+)["\"][^>]*>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    if (match == null) {
      return html;
    }
    final tag = match.group(0)!;
    final fileName = match.group(1)!;
    final data = await rootBundle.load('$_bundlePrefix$fileName');
    final bytes = data.buffer.asUint8List();
    final dataUri = 'data:image/x-icon;base64,${base64Encode(bytes)}';
    final replacement = tag.replaceFirst(fileName, dataUri);
    return html.replaceFirst(tag, replacement);
  }

  String _stripNoscript(String html) {
    return html.replaceAll(
      RegExp(r'<noscript>.*?</noscript>', dotAll: true),
      '',
    );
  }

  String _translationOrFallback(String key, String fallback) {
    final translation = _tr(key);
    if (translation.isEmpty) {
      return fallback;
    }
    return translation;
  }
}

class _RoomCreatorNotice extends StatelessWidget {
  const _RoomCreatorNotice({
    required this.title,
    required this.description,
    required this.message,
    required this.panelColor,
    this.wrapInSurface = false,
  });

  final String title;
  final String description;
  final String message;
  final Color panelColor;
  final bool wrapInSurface;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (!wrapInSurface) {
      return Center(child: body);
    }

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: body,
    );
  }
}

class _RoomCreatorLoading extends StatelessWidget {
  const _RoomCreatorLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: const Center(child: CircularProgressIndicator()),
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
