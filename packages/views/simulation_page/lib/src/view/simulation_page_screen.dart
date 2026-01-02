import 'dart:async';
import 'dart:convert';

import 'package:backend_gateway/backend_gateway.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:room_modeling/room_modeling.dart';
import 'package:uuid/uuid.dart';

import '../bloc/simulation_page_bloc.dart';
import 'simulation_results_chart.dart';

class SimulationPageScreen extends StatelessWidget {
  const SimulationPageScreen({super.key});

  static const String routeName = '/simulation';

  @override
  Widget build(BuildContext context) {
    final gatewayBloc = GetIt.instance<GatewayConnectionBloc>();
    final gatewayConfig = GetIt.instance<GatewayConfig>();
    final httpClient = BackendHttpClient(config: gatewayConfig);
    final referenceRepository = SimulationReferenceRepository(
      httpClient: httpClient,
    );
    final materialsRepository = SimulationMaterialsRepository(
      httpClient: httpClient,
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              SimulationPageBloc(referenceRepository: referenceRepository)
                ..add(const SimulationReferenceProfilesRequested()),
        ),
        BlocProvider(create: (_) => RoomModelingBloc()),
        BlocProvider.value(value: gatewayBloc),
      ],
      child: _SimulationPageView(materialsRepository: materialsRepository),
    );
  }
}

class _SimulationPageView extends StatefulWidget {
  const _SimulationPageView({required this.materialsRepository});

  final SimulationMaterialsRepository materialsRepository;

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
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final roomBloc = context.read<RoomModelingBloc>();
    roomBloc.add(const LoadMaterials());
    try {
      final materials = await widget.materialsRepository.fetchMaterials();
      final acousticMaterials = materials
          .map(
            (m) => AcousticMaterial(
              id: m.id,
              displayName: m.displayName,
              absorption: m.absorption,
              scattering: m.scattering,
            ),
          )
          .toList();
      roomBloc.add(MaterialsLoaded(acousticMaterials));
    } catch (e) {
      roomBloc.add(MaterialsLoadFailed(e.toString()));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSimulationDialog(
    BuildContext context, {
    bool useRaytracing = false,
    int raytracingBounces = 3,
  }) {
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
          useRaytracing: useRaytracing,
          raytracingBounces: raytracingBounces,
          onComplete: (result) {
            Navigator.of(context).pop();
            final simulationBloc = this.context.read<SimulationPageBloc>();
            simulationBloc.add(
              SimulationResultReceived(result, isRaytracing: useRaytracing),
            );
            // Advance to step 4 (results) only if not already there
            if (simulationBloc.state.activeStepIndex < 4) {
              simulationBloc.add(const SimulationTimelineAdvanced());
            }
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
            } else if (state.activeStepIndex == 1) {
              roomBloc.add(const StepChanged(RoomModelingStep.furnishing));
            } else {
              roomBloc.add(const StepChanged(RoomModelingStep.audio));
            }

            // Show simulation dialog when entering step 4 (index 3)
            if (state.activeStepIndex == 3) {
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
                            simulationState.activeStepIndex >= 3;
                        // Only show metrics in step 5 (results)
                        final showMetrics =
                            simulationState.activeStepIndex == 4;

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
                                readOnly: simulationState.activeStepIndex >= 3,
                              ),
                            ),
                            SizedBox(height: isWide ? 32 : 24),
                            const _SimulationTimelineCard(),
                            if (showMetrics) ...[
                              SizedBox(height: isWide ? 48 : 36),
                              _SimulationMetricSection(
                                key: _metricsKey,
                                onRaytracingPressed: (bounces) =>
                                    _showSimulationDialog(
                                      context,
                                      useRaytracing: true,
                                      raytracingBounces: bounces,
                                    ),
                              ),
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
    this.useRaytracing = false,
    this.raytracingBounces = 3,
  });

  final ValueChanged<Map<String, dynamic>?> onComplete;
  final GatewayConnectionBloc gatewayBloc;
  final GatewayConnectionRepository gatewayRepository;
  final RoomModelingBloc roomBloc;
  final bool useRaytracing;
  final int raytracingBounces;

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
        'data': {
          'room_model': roomJson,
          'include_rir': false,
          'use_raytracing': widget.useRaytracing,
          'raytracing_bounces': widget.raytracingBounces,
        },
      };
      debugPrint('Simulation request payload: ${jsonEncode(payload)}');
      await widget.gatewayRepository.sendJson(payload);
      debugPrint(
        'Simulation payload sent (requestId: $requestId, rooms: $roomCount, '
        'furniture: $furnitureCount, raytracing: ${widget.useRaytracing}, '
        'bounces: ${widget.raytracingBounces}, '
        'elapsed: ${timer.elapsedMilliseconds} ms)',
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

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      for (int i = 0; i < _tasks.length; i++) {
        _tasks[i] = _tasks[i].copyWith(
          status: _SimulationTaskStatus.pending,
          resetDetail: true,
        );
      }
    });
    _runWorkflow();
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SonalyzeButton(
                      onPressed: _retry,
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Text(_tr('common.retry')),
                    ),
                    const SizedBox(width: 12),
                    SonalyzeButton(
                      onPressed: () => Navigator.of(context).pop(),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      borderRadius: BorderRadius.circular(16),
                      child: Text(_tr('common.close')),
                    ),
                  ],
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

class _SimulationMetricSection extends StatefulWidget {
  const _SimulationMetricSection({super.key, this.onRaytracingPressed});

  final void Function(int bounces)? onRaytracingPressed;

  @override
  State<_SimulationMetricSection> createState() =>
      _SimulationMetricSectionState();
}

class _SimulationMetricSectionState extends State<_SimulationMetricSection> {
  int _selectedBounces = 5; // Default to medium (5 bounces)

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.metrics_background');
    final accentColor = _themeColor('simulation_page.timeline_active');
    final badgeColor = _themeColor('simulation_page.header_badge_background');
    final badgeText = _themeColor('simulation_page.header_badge_text');

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('simulation_page.results.title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.onRaytracingPressed != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _localizedOr(
                              'simulation_page.results.raytracing_badge',
                              'Experimental',
                            ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: badgeText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RaytracingPerformanceDropdown(
                          selectedBounces: _selectedBounces,
                          onChanged: (bounces) {
                            setState(() => _selectedBounces = bounces);
                          },
                        ),
                        const SizedBox(width: 8),
                        SonalyzeButton(
                          onPressed: () =>
                              widget.onRaytracingPressed!(_selectedBounces),
                          backgroundColor: accentColor.withValues(alpha: 0.15),
                          foregroundColor: accentColor,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          child: Text(
                            _localizedOr(
                              'simulation_page.results.raytracing_button',
                              'Raytracing Simulation',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (result != null) ...[
                SimulationResultsChart(
                  result: result,
                  raytracingResult: state.lastRaytracingResult,
                  referenceProfiles: state.referenceProfiles,
                  referenceStatus: state.referenceProfilesStatus,
                  referenceError: state.referenceProfilesError,
                ),
                if (result.warnings.any((w) => !w.contains('STI'))) ...[
                  const SizedBox(height: 24),
                  Text(
                    _localizedOr(
                      'simulation_page.results.warnings',
                      'Warnings',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final warning in result.warnings.where(
                        (w) => !w.contains('STI'),
                      ))
                        _ResultWarningChip(label: warning),
                    ],
                  ),
                ],
              ] else
                const _SimulationResultsEmptyState(),
            ],
          ),
        );
      },
    );
  }
}

enum _RaytracingPerformance {
  fast(3, 'Fast'),
  medium(5, 'Medium'),
  high(7, 'High'),
  extreme(10, 'Extreme'),
  bonkers(15, 'Bonkers'),
  bonkersPlus(20, 'Bonkers+'),
  serverCrasher(30, 'Servercrasher');

  const _RaytracingPerformance(this.bounces, this.label);
  final int bounces;
  final String label;

  String localizedLabel(BuildContext context) {
    final key = 'simulation_page.results.raytracing_performance.$name';
    return _localizedOr(key, label);
  }

  static _RaytracingPerformance fromBounces(int bounces) {
    return _RaytracingPerformance.values.firstWhere(
      (p) => p.bounces == bounces,
      orElse: () => _RaytracingPerformance.medium,
    );
  }
}

class _RaytracingPerformanceDropdown extends StatelessWidget {
  const _RaytracingPerformanceDropdown({
    required this.selectedBounces,
    required this.onChanged,
  });

  final int selectedBounces;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final accentColor = _themeColor('simulation_page.timeline_active');
    final selected = _RaytracingPerformance.fromBounces(selectedBounces);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_RaytracingPerformance>(
          value: selected,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: accentColor, size: 20),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: _RaytracingPerformance.values.map((performance) {
            return DropdownMenuItem(
              value: performance,
              child: Text(
                '${performance.localizedLabel(context)} (${performance.bounces})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: (performance) {
            if (performance != null) {
              onChanged(performance.bounces);
            }
          },
          selectedItemBuilder: (context) {
            return _RaytracingPerformance.values.map((performance) {
              return Center(
                child: Text(
                  performance.localizedLabel(context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList();
          },
        ),
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

class _SimulationResultsEmptyState extends StatelessWidget {
  const _SimulationResultsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      _localizedOr(
        'simulation_page.results.empty',
        'Run a simulation to preview responses from the backend.',
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
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
            final requiresDevices = simulationState.activeStepIndex == 2;
            final hasSpeaker = roomState.furniture.any(
              (f) => f.type == FurnitureType.speaker,
            );
            final hasMic = roomState.furniture.any(
              (f) => f.type == FurnitureType.microphone,
            );
            final hasRequiredDevices = hasSpeaker && hasMic;

            final canAdvance =
                simulationState.steps.isNotEmpty &&
                ((simulationState.activeStepIndex > 0 ||
                        roomState.isRoomClosed) &&
                    (!requiresDevices || hasRequiredDevices));

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
                  if (requiresDevices && !hasRequiredDevices)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        _tr(
                          'simulation_page.timeline.place_devices_hint',
                          fallback:
                              'Place at least one speaker and one microphone to continue.',
                        ),
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
                Text(
                  _tr(descriptor.titleKey, fallback: descriptor.fallbackTitle),
                  style: titleStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  _tr(
                    descriptor.descriptionKey,
                    fallback: descriptor.fallbackDescription,
                  ),
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
        ],
      ),
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

String _localizedOr(String keyPath, String fallback) {
  final value = _tr(keyPath);
  return value.isNotEmpty ? value : fallback;
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  return AppConstants.getThemeColors(keyPath);
}
