import 'dart:async';
import 'dart:convert';

import 'package:backend_gateway/backend_gateway.dart';
import 'package:common_helpers/common_helpers.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:room_modeling/room_modeling.dart';
import 'package:uuid/uuid.dart';

import '../bloc/simulation_page_bloc.dart';

class SimulationPageScreen extends StatelessWidget {
  const SimulationPageScreen({super.key});

  static const String routeName = '/simulation';

  @override
  Widget build(BuildContext context) {
    final gatewayBloc = GetIt.instance<GatewayConnectionBloc>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SimulationPageBloc()),
        BlocProvider(create: (_) => RoomModelingBloc()),
        BlocProvider.value(value: gatewayBloc),
      ],
      child: const _SimulationPageView(),
    );
  }
}

class _SimulationPageView extends StatefulWidget {
  const _SimulationPageView();

  @override
  State<_SimulationPageView> createState() => _SimulationPageViewState();
}

class _SimulationPageViewState extends State<_SimulationPageView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _metricsKey = GlobalKey();
  bool _isSimulationDialogShowing = false;
  final GatewayConnectionRepository _gatewayRepository =
      GetIt.instance<GatewayConnectionRepository>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSimulationDialog(BuildContext context) {
    if (_isSimulationDialogShowing) return;
    _isSimulationDialogShowing = true;
    final gatewayBloc = context.read<GatewayConnectionBloc>();
    final roomBloc = context.read<RoomModelingBloc>();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _SimulationProgressDialog(
          gatewayBloc: gatewayBloc,
          gatewayRepository: _gatewayRepository,
          roomBloc: roomBloc,
          onComplete: (result) {
            Navigator.of(context).pop();
            final simulationBloc = this.context.read<SimulationPageBloc>();
            simulationBloc.add(SimulationResultReceived(result));
            // Advance to step 4 (results)
            simulationBloc.add(const SimulationTimelineAdvanced());
            // Scroll to results after a short delay
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollToMetrics();
            });
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    ).then((_) {
      _isSimulationDialogShowing = false;
    });
  }

  void _scrollToMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_metricsKey.currentContext != null) {
        final renderBox =
            _metricsKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final scrollOffset =
              _scrollController.offset +
              position.dy -
              MediaQuery.of(context).padding.top -
              100;
          _scrollController.animateTo(
            scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = _themeColors(
      'simulation_page.background_gradient',
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<SimulationPageBloc, SimulationPageState>(
          listenWhen: (previous, current) =>
              previous.activeStepIndex != current.activeStepIndex,
          listener: (context, state) {
            // Sync room modeling step with simulation step
            final roomBloc = context.read<RoomModelingBloc>();
            if (state.activeStepIndex == 0) {
              roomBloc.add(const StepChanged(RoomModelingStep.structure));
            } else if (state.activeStepIndex >= 1) {
              roomBloc.add(const StepChanged(RoomModelingStep.furnishing));
            }

            // Show simulation dialog when entering step 3 (index 2)
            if (state.activeStepIndex == 2) {
              _showSimulationDialog(context);
            }
          },
        ),
      ],
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
                    controller: _scrollController,
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
                              _SimulationMetricSection(key: _metricsKey),
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

class _SimulationProgressDialog extends StatefulWidget {
  const _SimulationProgressDialog({
    required this.onComplete,
    required this.gatewayBloc,
    required this.gatewayRepository,
    required this.roomBloc,
  });

  final ValueChanged<Map<String, dynamic>?> onComplete;
  final GatewayConnectionBloc gatewayBloc;
  final GatewayConnectionRepository gatewayRepository;
  final RoomModelingBloc roomBloc;

  @override
  State<_SimulationProgressDialog> createState() =>
      _SimulationProgressDialogState();
}

class _SimulationProgressDialogState extends State<_SimulationProgressDialog> {
  static const Duration _connectionTimeout = Duration(seconds: 12);
  static const Duration _simulationTimeout = Duration(seconds: 45);
  static const Uuid _uuid = Uuid();

  final List<_SimulationTask> _tasks = <_SimulationTask>[
    const _SimulationTask(label: 'Connection to backend successful'),
    const _SimulationTask(label: 'Data sent to backend successful'),
    const _SimulationTask(label: 'Simulation completed'),
  ];

  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runWorkflow();
  }

  Future<void> _runWorkflow() async {
    final workflowTimer = Stopwatch()..start();
    String? requestId;
    try {
      await _ensureConnected();
      requestId = _uuid.v4();
      debugPrint('Simulation workflow started (requestId: $requestId)');
      final responseFuture = _responseFor(requestId);
      await _sendSimulationPayload(requestId);
      debugPrint('Awaiting simulation response (requestId: $requestId)');
      final envelope = await _awaitSimulationCompletion(
        responseFuture,
        requestId,
      );
      if (!mounted) {
        return;
      }
      debugPrint(
        'Simulation workflow finished in ${workflowTimer.elapsedMilliseconds} ms '
        '(requestId: $requestId)',
      );
      widget.onComplete(_payloadAsJsonMap(envelope.data));
    } catch (error, stackTrace) {
      debugPrint(
        'Simulation workflow failed (requestId: ${requestId ?? 'n/a'}): $error',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }

  Future<void> _ensureConnected() async {
    final timer = Stopwatch()..start();
    debugPrint('Ensuring gateway connection...');
    _updateTask(0, _SimulationTaskStatus.active);
    final bloc = widget.gatewayBloc;
    if (bloc.state.status == GatewayConnectionStatus.connected) {
      _updateTask(0, _SimulationTaskStatus.success);
      debugPrint('Gateway already connected.');
      return;
    }
    if (bloc.state.status == GatewayConnectionStatus.failure ||
        bloc.state.status == GatewayConnectionStatus.disconnected ||
        bloc.state.status == GatewayConnectionStatus.initial) {
      bloc.add(const GatewayConnectionRequested());
    }
    try {
      await bloc.stream
          .firstWhere(
            (state) => state.status == GatewayConnectionStatus.connected,
          )
          .timeout(_connectionTimeout);
      _updateTask(0, _SimulationTaskStatus.success);
      debugPrint('Gateway connected in ${timer.elapsedMilliseconds} ms.');
    } on Object catch (error) {
      _updateTask(0, _SimulationTaskStatus.failure, detail: error.toString());
      debugPrint('Gateway connection failed: $error');
      rethrow;
    }
  }

  Future<void> _sendSimulationPayload(String requestId) async {
    final timer = Stopwatch()..start();
    _updateTask(1, _SimulationTaskStatus.active);
    try {
      final exporter = RoomPlanExporter();
      final roomJson = exporter.export(widget.roomBloc.state);
      final rooms = roomJson['rooms'];
      final roomCount = rooms is List ? rooms.length : 0;
      final furnitureCount = rooms is List && rooms.isNotEmpty
          ? ((rooms.first as Map<String, dynamic>)['furniture'] as List?)
                    ?.length ??
                0
          : 0;
      final payload = <String, dynamic>{
        'event': 'simulation.run',
        'request_id': requestId,
        'data': {'room_model': roomJson, 'include_rir': false},
      };
      debugPrint('Simulation request payload: ${jsonEncode(payload)}');
      await widget.gatewayRepository.sendJson(payload);
      debugPrint(
        'Simulation payload sent (requestId: $requestId, rooms: $roomCount, '
        'furniture: $furnitureCount, elapsed: ${timer.elapsedMilliseconds} ms)',
      );
      _updateTask(1, _SimulationTaskStatus.success);
    } on Object catch (error) {
      _updateTask(1, _SimulationTaskStatus.failure, detail: error.toString());
      debugPrint(
        'Simulation payload send failed (requestId: $requestId): $error',
      );
      rethrow;
    }
  }

  Future<GatewayEnvelope> _awaitSimulationCompletion(
    Future<GatewayEnvelope> responseFuture,
    String requestId,
  ) async {
    final timer = Stopwatch()..start();
    _updateTask(2, _SimulationTaskStatus.active);
    try {
      final envelope = await responseFuture;
      if (envelope.isError) {
        final message = jsonEncode(envelope.error ?? {'message': 'error'});
        throw StateError('Simulation failed: $message');
      }
      if (envelope.data != null) {
        debugPrint('Simulation completed result: ${jsonEncode(envelope.data)}');
      }
      final responseId = envelope.requestId ?? 'n/a';
      debugPrint(
        'Simulation completed successfully (requestId: $requestId, '
        'responseId: $responseId, elapsed: ${timer.elapsedMilliseconds} ms)',
      );
      _updateTask(2, _SimulationTaskStatus.success);
      return envelope;
    } on Object catch (error) {
      _updateTask(2, _SimulationTaskStatus.failure, detail: error.toString());
      debugPrint(
        'Simulation response wait failed (requestId: $requestId): $error',
      );
      rethrow;
    }
  }

  Future<GatewayEnvelope> _responseFor(String requestId) {
    return widget.gatewayBloc.envelopes
        .where(
          (envelope) =>
              envelope.requestId == requestId &&
              envelope.event == 'simulation.run',
        )
        .first
        .timeout(_simulationTimeout);
  }

  Map<String, dynamic>? _payloadAsJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  void _updateTask(int index, _SimulationTaskStatus status, {String? detail}) {
    if (!mounted || index < 0 || index >= _tasks.length) {
      return;
    }
    setState(() {
      final shouldClearDetail =
          detail == null &&
          status != _SimulationTaskStatus.failure &&
          status != _SimulationTaskStatus.pending;
      _tasks[index] = _tasks[index].copyWith(
        status: status,
        detail: detail,
        resetDetail: shouldClearDetail,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final panelColor = _themeColor('simulation_page.metrics_background');
    final accentColor = _themeColor('simulation_page.timeline_active');

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tr('simulation_page.progress.title'),
                style: textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _tr('simulation_page.progress.description'),
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              for (final task in _tasks) ...[
                _ProgressStatusRow(task: task, accentColor: accentColor),
                const SizedBox(height: 16),
              ],
              if (_hasError) ...[
                Text(
                  _errorMessage ?? 'Simulation failed.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                SonalyzeButton(
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  borderRadius: BorderRadius.circular(16),
                  child: Text(_tr('common.close')),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStatusRow extends StatelessWidget {
  const _ProgressStatusRow({required this.task, required this.accentColor});

  final _SimulationTask task;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    late final Widget icon;
    late final Color detailColor;

    switch (task.status) {
      case _SimulationTaskStatus.success:
        icon = Icon(Icons.check_circle, color: accentColor, size: 28);
        detailColor = accentColor;
        break;
      case _SimulationTaskStatus.failure:
        icon = Icon(Icons.error, color: colorScheme.error, size: 28);
        detailColor = colorScheme.error;
        break;
      case _SimulationTaskStatus.active:
        icon = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        );
        detailColor = accentColor;
        break;
      case _SimulationTaskStatus.pending:
      default:
        final faded = colorScheme.onSurface.withValues(alpha: 0.3);
        icon = Icon(Icons.radio_button_unchecked, color: faded, size: 24);
        detailColor = faded;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (task.detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    task.detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: detailColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _SimulationTaskStatus { pending, active, success, failure }

class _SimulationTask {
  const _SimulationTask({
    required this.label,
    this.status = _SimulationTaskStatus.pending,
    this.detail,
  });

  final String label;
  final _SimulationTaskStatus status;
  final String? detail;

  _SimulationTask copyWith({
    _SimulationTaskStatus? status,
    String? detail,
    bool resetDetail = false,
  }) {
    return _SimulationTask(
      label: label,
      status: status ?? this.status,
      detail: resetDetail ? null : (detail ?? this.detail),
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
    final accentColor = _themeColor('simulation_page.timeline_active');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: accentColor),
          tooltip: _tr('common.back'),
          style: IconButton.styleFrom(
            backgroundColor: accentColor.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
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
  const _SimulationMetricSection({super.key});

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.metrics_background');

    return BlocBuilder<SimulationPageBloc, SimulationPageState>(
      builder: (context, state) {
        final result = state.lastResult;
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
              if (result != null)
                _SimulationResultCards(result: result)
              else
                _SimulationMetricsPlaceholder(series: state.metrics),
            ],
          ),
        );
      },
    );
  }
}

class _SimulationMetricsPlaceholder extends StatelessWidget {
  const _SimulationMetricsPlaceholder({required this.series});

  final List<SimulationMetricSeries> series;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (series.isEmpty) {
          return Text(
            _localizedOr(
              'simulation_page.results.empty',
              'Run a simulation to preview estimated responses.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          );
        }
        final isWide = constraints.maxWidth > 1000;
        final itemWidth = isWide
            ? (constraints.maxWidth - 32) / 3
            : double.infinity;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final metric in series)
              SizedBox(
                width: itemWidth,
                child: _MetricChartCard(series: metric),
              ),
          ],
        );
      },
    );
  }
}

class _SimulationResultCards extends StatelessWidget {
  const _SimulationResultCards({required this.result});

  final SimulationResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ResultInfoChip(
              icon: Icons.graphic_eq,
              label: _localizedOr(
                'simulation_page.results.sample_rate',
                'Sample rate',
              ),
              value: '${result.sampleRateHz} Hz',
            ),
            _ResultInfoChip(
              icon: Icons.blur_linear,
              label: _localizedOr(
                'simulation_page.results.pair_count',
                'Source/Mic pairs',
              ),
              value: '${result.pairs.length}',
            ),
          ],
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _localizedOr('simulation_page.results.warnings', 'Warnings'),
            style: textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final warning in result.warnings)
                _ResultWarningChip(label: warning),
            ],
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            final itemWidth = isWide
                ? (constraints.maxWidth - 32) / 2
                : double.infinity;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final pair in result.pairs)
                  SizedBox(
                    width: itemWidth,
                    child: _SimulationResultCard(pair: pair),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SimulationResultCard extends StatelessWidget {
  const _SimulationResultCard({required this.pair});

  final SimulationResultPair pair;

  @override
  Widget build(BuildContext context) {
    final cardColor = _themeColor('simulation_page.graphs.card_background');
    final heading =
        _localizedOr(
              'simulation_page.results.pair_heading',
              'Source {source} → Mic {mic}',
            )
            .replaceAll('{source}', pair.sourceId)
            .replaceAll('{mic}', pair.microphoneId);
    final metricData = _buildResultMetricData(pair.metrics);

    return SonalyzeSurface(
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (metricData.isEmpty)
            Text(
              _localizedOr(
                'simulation_page.results.no_metrics',
                'No metrics available for this pair.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final data in metricData) _MetricValueChip(data: data),
              ],
            ),
          if (pair.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _localizedOr('simulation_page.results.warnings', 'Warnings'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final warning in pair.warnings)
                  _ResultWarningChip(label: warning),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricValueChip extends StatelessWidget {
  const _MetricValueChip({required this.data});

  final _MetricValueData data;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = _themeColor('simulation_page.metrics_background');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (data.unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  data.unit!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          if (data.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              data.detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultInfoChip extends StatelessWidget {
  const _ResultInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = _themeColor('simulation_page.metrics_background');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultWarningChip extends StatelessWidget {
  const _ResultWarningChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final warningColor = _themeColor('simulation_page.timeline_inactive');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: warningColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricValueData {
  const _MetricValueData({
    required this.label,
    required this.value,
    this.unit,
    this.detail,
  });

  final String label;
  final String value;
  final String? unit;
  final String? detail;
}

List<_MetricValueData> _buildResultMetricData(SimulationResultMetrics metrics) {
  final items = <_MetricValueData>[];

  void addMetric({
    required String labelKey,
    required String fallbackLabel,
    String? unitKey,
    String? fallbackUnit,
    String? value,
    String? detail,
  }) {
    if (value == null) {
      return;
    }
    String? unit;
    if (unitKey != null || fallbackUnit != null) {
      final resolved = unitKey != null
          ? _localizedOr(unitKey, fallbackUnit ?? '')
          : (fallbackUnit ?? '');
      unit = resolved.isEmpty ? null : resolved;
    }
    items.add(
      _MetricValueData(
        label: _localizedOr(labelKey, fallbackLabel),
        value: value,
        unit: unit,
        detail: detail,
      ),
    );
  }

  addMetric(
    labelKey: 'simulation_page.metrics.rt60.label',
    fallbackLabel: 'RT60',
    unitKey: 'simulation_page.metrics.rt60.unit',
    fallbackUnit: 's',
    value: _formatSecondsValue(metrics.rt60Seconds),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.edt.label',
    fallbackLabel: 'EDT',
    fallbackUnit: 's',
    value: _formatSecondsValue(metrics.edtSeconds),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.d50.label',
    fallbackLabel: 'D50',
    value: _formatRatioValue(metrics.earlyDecay50),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.c50.label',
    fallbackLabel: 'C50',
    fallbackUnit: 'dB',
    value: _formatDbValue(metrics.clarity50Db),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.c80.label',
    fallbackLabel: 'C80',
    fallbackUnit: 'dB',
    value: _formatDbValue(metrics.clarity80Db),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.drr.label',
    fallbackLabel: 'DRR',
    fallbackUnit: 'dB',
    value: _formatDbValue(metrics.directToReverberantDb),
  );
  addMetric(
    labelKey: 'simulation_page.metrics.sti.label',
    fallbackLabel: 'STI',
    value: _formatRatioValue(metrics.sti),
    detail: metrics.stiMethod,
  );

  return items;
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
    final backColor = _themeColor('simulation_page.timeline_back');
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
                            backgroundColor: backColor,
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

String _localizedOr(String keyPath, String fallback) {
  final value = _tr(keyPath);
  return value.isNotEmpty ? value : fallback;
}

String? _formatSecondsValue(double? value) {
  if (value == null) {
    return null;
  }
  return formatNumber(value, fractionDigits: 2);
}

String? _formatDbValue(double? value) {
  if (value == null) {
    return null;
  }
  return formatNumber(value, fractionDigits: 1);
}

String? _formatRatioValue(double? value) {
  if (value == null) {
    return null;
  }
  return formatNumber(value, fractionDigits: 2);
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  return AppConstants.getThemeColors(keyPath);
}
