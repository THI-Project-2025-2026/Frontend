import 'dart:async';
import 'dart:math' as math;
import 'package:backend_gateway/backend_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'measurement_page_event.dart';
part 'measurement_page_state.dart';

/// Bloc orchestrating collaborative measurement sessions.
///
/// Handles lobby creation, invite link / QR toggles, role selection, device
/// discovery, readiness toggles, and synthesises telemetry shown on the demo UI.
class MeasurementPageBloc
    extends Bloc<MeasurementPageEvent, MeasurementPageState> {
  MeasurementPageBloc({
    required GatewayConnectionRepository repository,
    required GatewayConnectionBloc gatewayBloc,
    required BackendHttpClient httpClient,
    required String localDeviceId,
  }) : _repository = repository,
       _gatewayBloc = gatewayBloc,
       _httpClient = httpClient,
       _localDeviceId = localDeviceId,
       super(MeasurementPageState.initial()) {
    on<MeasurementLobbyCreated>(_onLobbyCreated);
    on<MeasurementLobbyJoined>(_onLobbyJoined);
    on<MeasurementLobbyRefreshed>(_onLobbyRefreshed);
    on<MeasurementLobbyQrToggled>(_onLobbyQrToggled);
    // on<MeasurementLobbyCodeRefreshed>(_onLobbyCodeRefreshed);
    on<MeasurementLobbyLinkCopied>(_onLobbyLinkCopied);
    on<MeasurementDeviceRoleChanged>(_onDeviceRoleChanged);
    on<MeasurementDeviceReadyToggled>(_onDeviceReadyToggled);
    on<MeasurementTimelineAdvanced>(_onTimelineAdvanced);
    on<MeasurementTimelineStepBack>(_onTimelineStepBack);
    on<MeasurementRoomPlanReceived>(_onRoomPlanReceived);
    on<MeasurementProfileChanged>(_onProfileChanged);
    on<MeasurementSweepStartRequested>(_onSweepStartRequested);
    on<MeasurementSweepCancelled>(_onSweepCancelled);
    on<MeasurementJobCreated>(_onJobCreated);
    on<_MeasurementStartReceived>(_onMeasurementStartReceived);
    on<_SessionStateChanged>(_onSessionStateChanged);
    on<_AnalysisRequested>(_onAnalysisRequested);
    on<_AnalysisResultsReceived>(_onAnalysisResultsReceived);
    on<_AnalysisFailed>(_onAnalysisFailed);

    _gatewaySubscription = _gatewayBloc.envelopes.listen((envelope) {
      if (!envelope.isEvent) {
        return;
      }
      if (envelope.event == 'lobby.updated') {
        add(const MeasurementLobbyRefreshed());
        return;
      }
      if (envelope.event == 'lobby.room_snapshot') {
        final data = envelope.data;
        if (data is! Map<String, dynamic>) {
          return;
        }
        final lobbyId = data['lobby_id'] as String?;
        final room = data['room'];
        if (lobbyId == null || lobbyId.isEmpty) {
          return;
        }
        if (lobbyId != state.lobbyId) {
          return;
        }
        if (room is Map<String, dynamic>) {
          add(
            MeasurementRoomPlanReceived(
              roomJson: Map<String, dynamic>.from(room),
            ),
          );
        }
      }
      // Handle measurement start notification for non-admin devices
      if (envelope.event == 'measurement.start_measurement') {
        final data = envelope.data;
        if (data is! Map<String, dynamic>) {
          return;
        }
        // Only handle if we don't already have a session bloc running
        if (_sessionBloc == null) {
          add(
            _MeasurementStartReceived(
              sessionId: data['session_id'] as String? ?? '',
              jobId: data['job_id'] as String? ?? '',
              speakerDeviceId: data['speaker_device_id'] as String? ?? '',
              speakerSlotId: data['current_speaker_slot_id'] as String? ?? '',
            ),
          );
        }
      }
    });
  }

  final GatewayConnectionRepository _repository;
  final GatewayConnectionBloc _gatewayBloc;
  final BackendHttpClient _httpClient;
  final String _localDeviceId;
  StreamSubscription? _gatewaySubscription;
  MeasurementSessionBloc? _sessionBloc;
  StreamSubscription? _sessionSubscription;

  @override
  Future<void> close() async {
    debugPrint(
      '[NAV_DEBUG] MeasurementPageBloc.close() called - BLOC IS BEING CLOSED',
    );
    debugPrint('[NAV_DEBUG] Stack trace: ${StackTrace.current}');
    await _gatewaySubscription?.cancel();
    await _sessionSubscription?.cancel();
    await _sessionBloc?.close();
    return super.close();
  }

  Future<void> _onLobbyCreated(
    MeasurementLobbyCreated event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.create',
        'request_id': requestId,
        'data': <String, dynamic>{},
      });

      final response = await responseFuture;
      if (response.error != null) {
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String;
      final lobbyId = data['lobby_id'] as String;
      final adminDeviceId = data['admin_device_id'] as String;
      // We assume the creator is the current device, but we don't have our own device ID easily accessible here
      // unless we store it or get it from the gateway.
      // However, for 'create', we are definitely the host.

      emit(
        state.copyWith(
          lobbyCode: code,
          lobbyId: lobbyId,
          inviteLink: 'https://sonalyze.app/join/$code',
          lobbyActive: true,
          lastActionMessage: 'measurement_page.lobby.status_active',
          isHost: true,
          currentDeviceId: adminDeviceId, // In create, we are the admin
          activeStepIndex: math.max(state.activeStepIndex, 1),
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onLobbyJoined(
    MeasurementLobbyJoined event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.join',
        'request_id': requestId,
        'data': {'code': event.code},
      });

      final response = await responseFuture;
      if (response.error != null) {
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String;
      final lobbyId = data['lobby_id'] as String;
      // final adminDeviceId = data['admin_device_id'] as String;

      // We need to know OUR device ID to check if we are host.
      // The join response might not return OUR device ID explicitly if we don't look for it.
      // But wait, the gateway connection has a device_id.
      // For now, let's assume we are NOT host if we join (unless we rejoin our own lobby).
      // Actually, we should fetch the lobby details which includes participants.

      final participants = (data['participants'] as List)
          .cast<Map<String, dynamic>>();
      final devices = _mapParticipantsToDevices(participants);

      // To find out who WE are, we might need to ask the gateway 'identify' or check the response.
      // But for now, let's assume if we join, we are not the host initially unless the IDs match.
      // Since we don't have our ID easily, we'll rely on the fact that 'create' sets isHost=true.
      // If we join, we are likely not the host.
      // TODO: Get actual device ID from GatewayBloc or Repository.

      emit(
        state.copyWith(
          lobbyCode: code,
          lobbyId: lobbyId,
          inviteLink: 'https://sonalyze.app/join/$code',
          lobbyActive: true,
          lastActionMessage: 'measurement_page.lobby.status_active',
          devices: devices,
          isHost: false, // Assumption for now
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onLobbyRefreshed(
    MeasurementLobbyRefreshed event,
    Emitter<MeasurementPageState> emit,
  ) async {
    if (!state.lobbyActive || state.lobbyCode.isEmpty) return;

    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.get',
        'request_id': requestId,
        'data': {'code': state.lobbyCode},
      });

      final response = await responseFuture;
      if (response.error != null) return;

      final data = response.data as Map<String, dynamic>;
      final lobbyId = data['lobby_id'] as String;
      final participants = (data['participants'] as List)
          .cast<Map<String, dynamic>>();
      final devices = _mapParticipantsToDevices(participants);

      emit(state.copyWith(devices: devices, lobbyId: lobbyId));
    } catch (e) {
      // Handle error
    }
  }

  List<MeasurementDevice> _mapParticipantsToDevices(
    List<Map<String, dynamic>> participants,
  ) {
    return participants.map((p) {
      final deviceId = p['device_id'] as String;
      final roleStr = p['role'] as String;
      final role = MeasurementDeviceRole.values.firstWhere(
        (e) => _mapRoleToBackend(e) == roleStr,
        orElse: () => MeasurementDeviceRole.none,
      );
      final existing = _findExistingDevice(deviceId);
      MeasurementDevice? roleSource;
      if (existing != null &&
          existing.roleSlotId != null &&
          existing.role == role &&
          role != MeasurementDeviceRole.none) {
        roleSource = existing;
      }
      final slotId = p['role_slot_id'] as String?;
      final slotLabel = p['role_slot_label'] as String?;

      return MeasurementDevice(
        id: deviceId,
        name: existing?.name ?? 'Device ${deviceId.substring(0, 4)}',
        role: role,
        isLocal: deviceId == state.currentDeviceId,
        isReady: existing?.isReady ?? false,
        latencyMs: existing?.latencyMs ?? 0,
        batteryLevel: existing?.batteryLevel ?? 1.0,
        roleSlotId: slotId ?? roleSource?.roleSlotId,
        roleLabel: slotLabel ?? roleSource?.roleLabel,
        roleColor: roleSource?.roleColor,
      );
    }).toList();
  }

  MeasurementDevice? _findExistingDevice(String deviceId) {
    for (final device in state.devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  String _mapRoleToBackend(MeasurementDeviceRole role) {
    switch (role) {
      case MeasurementDeviceRole.microphone:
        return 'microphone';
      case MeasurementDeviceRole.loudspeaker:
        return 'speaker';
      case MeasurementDeviceRole.none:
        return 'none';
    }
  }

  void _onLobbyQrToggled(
    MeasurementLobbyQrToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(state.copyWith(showQr: !state.showQr));
  }

  void _onLobbyLinkCopied(
    MeasurementLobbyLinkCopied event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(
      state.copyWith(lastActionMessage: 'measurement_page.lobby.link_copied'),
    );
  }

  Future<void> _onDeviceRoleChanged(
    MeasurementDeviceRoleChanged event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final devices = state.devices
        .map((device) {
          if (device.id == event.deviceId) {
            return device.copyWith(
              role: event.role,
              roleSlotId: event.roleSlotId,
              roleLabel: event.roleLabel,
              roleColor: event.roleColor,
            );
          }
          return device;
        })
        .toList(growable: false);

    emit(state.copyWith(devices: devices));

    if (!state.lobbyActive || state.lobbyId.isEmpty) return;

    final requestId = _generateRequestId();
    try {
      await _repository.sendJson({
        'event': 'role.assign',
        'request_id': requestId,
        'data': {
          'lobby_id': state.lobbyId,
          'target_device_id': event.deviceId,
          'role': _mapRoleToBackend(event.role),
          'role_slot_id': event.roleSlotId,
          'role_slot_label': event.roleLabel,
        },
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onDeviceReadyToggled(
    MeasurementDeviceReadyToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    final devices = state.devices
        .map((device) {
          if (device.id == event.deviceId) {
            return device.copyWith(isReady: !device.isReady);
          }
          return device;
        })
        .toList(growable: false);

    emit(state.copyWith(devices: devices));
  }

  void _onTimelineAdvanced(
    MeasurementTimelineAdvanced event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (state.steps.isEmpty) {
      return;
    }
    final lastIndex = state.steps.length - 1;
    final nextIndex = math.min(state.activeStepIndex + 1, lastIndex);
    emit(state.copyWith(activeStepIndex: nextIndex));
  }

  void _onTimelineStepBack(
    MeasurementTimelineStepBack event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (state.steps.isEmpty) {
      return;
    }
    final prevIndex = math.max(state.activeStepIndex - 1, 0);
    emit(state.copyWith(activeStepIndex: prevIndex));
  }

  void _onRoomPlanReceived(
    MeasurementRoomPlanReceived event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(
      state.copyWith(
        sharedRoomPlan: event.roomJson,
        sharedRoomPlanVersion: state.sharedRoomPlanVersion + 1,
      ),
    );
  }

  void _onProfileChanged(
    MeasurementProfileChanged event,
    Emitter<MeasurementPageState> emit,
  ) {
    debugPrint(
      '[MeasurementPageBloc] Profile changed to: ${event.profile.id} '
      '(${event.profile.sweepFStart}Hz - ${event.profile.sweepFEnd}Hz)',
    );
    emit(state.copyWith(measurementProfile: event.profile));
  }

  String _generateRequestId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<GatewayEnvelope> _waitForResponse(String requestId) {
    return _gatewayBloc.envelopes
        .firstWhere((e) => e.requestId == requestId)
        .timeout(const Duration(seconds: 10));
  }

  /// Starts the sweep measurement process.
  ///
  /// Flow:
  /// 1. Create a measurement job on the server
  /// 2. Create a measurement session with speaker/microphone assignments
  /// 3. Start the measurement session (server coordinates sync)
  /// 4. Each speaker plays the audio while microphones record
  /// 5. Recordings are uploaded and analyzed
  Future<void> _onSweepStartRequested(
    MeasurementSweepStartRequested event,
    Emitter<MeasurementPageState> emit,
  ) async {
    debugPrint('[MeasurementPageBloc] _onSweepStartRequested called');
    debugPrint(
      '[MeasurementPageBloc] lobbyActive=${state.lobbyActive}, lobbyId=${state.lobbyId}',
    );

    if (!state.lobbyActive || state.lobbyId.isEmpty) {
      debugPrint('[MeasurementPageBloc] ERROR: No active lobby');
      emit(
        state.copyWith(
          sweepStatus: SweepStatus.failed,
          sweepError: 'No active lobby',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        sweepStatus: SweepStatus.creatingJob,
        sweepError: null,
        playbackPhase: PlaybackPhase.idle,
      ),
    );

    try {
      // Step 1: Create measurement job
      final requestId = _generateRequestId();
      final responseFuture = _waitForResponse(requestId);

      final payload = {
        'event': 'measurement.create_job',
        'request_id': requestId,
        'data': {
          'map': state.sharedRoomPlan ?? {},
          'meta': {'lobby_id': state.lobbyId, 'lobby_code': state.lobbyCode},
        },
      };
      debugPrint(
        '[MeasurementPageBloc] Sending measurement.create_job: $payload',
      );

      await _repository.sendJson(payload);

      debugPrint('[MeasurementPageBloc] Waiting for response...');
      final response = await responseFuture;
      debugPrint(
        '[MeasurementPageBloc] Received response: data=${response.data}, error=${response.error}',
      );

      if (response.error != null) {
        throw Exception('Failed to create job: ${response.error}');
      }

      final data = response.data as Map<String, dynamic>;
      final jobId = data['job_id'] as String;
      debugPrint('[MeasurementPageBloc] Job created with ID: $jobId');
      add(MeasurementJobCreated(jobId: jobId));
    } catch (e, stackTrace) {
      debugPrint('[MeasurementPageBloc] ERROR in _onSweepStartRequested: $e');
      debugPrint('[MeasurementPageBloc] Stack trace: $stackTrace');
      emit(
        state.copyWith(
          sweepStatus: SweepStatus.failed,
          sweepError: e.toString(),
        ),
      );
    }
  }

  Future<void> _onJobCreated(
    MeasurementJobCreated event,
    Emitter<MeasurementPageState> emit,
  ) async {
    debugPrint('[MeasurementPageBloc] _onJobCreated: jobId=${event.jobId}');

    emit(
      state.copyWith(
        jobId: event.jobId,
        sweepStatus: SweepStatus.creatingSession,
      ),
    );

    try {
      // Build speaker and microphone lists from device assignments
      final speakers = <SpeakerInfo>[];
      final microphones = <MicrophoneInfo>[];

      debugPrint(
        '[MeasurementPageBloc] Building speaker/mic lists from ${state.devices.length} devices',
      );
      for (final device in state.devices) {
        debugPrint(
          '[MeasurementPageBloc] Device: id=${device.id}, role=${device.role}, slotId=${device.roleSlotId}',
        );
        if (device.role == MeasurementDeviceRole.loudspeaker &&
            device.roleSlotId != null) {
          speakers.add(
            SpeakerInfo(
              deviceId: device.id,
              slotId: device.roleSlotId!,
              slotLabel: device.roleLabel,
            ),
          );
        } else if (device.role == MeasurementDeviceRole.microphone &&
            device.roleSlotId != null) {
          microphones.add(
            MicrophoneInfo(
              deviceId: device.id,
              slotId: device.roleSlotId!,
              slotLabel: device.roleLabel,
            ),
          );
        }
      }

      debugPrint(
        '[MeasurementPageBloc] Found ${speakers.length} speakers, ${microphones.length} microphones',
      );

      if (speakers.isEmpty || microphones.isEmpty) {
        throw Exception('At least one speaker and one microphone are required');
      }

      // Create and configure the measurement session BLoC
      debugPrint(
        '[MeasurementPageBloc] Creating MeasurementSessionBloc with httpClient=${_httpClient.baseUrl}, deviceId=$_localDeviceId',
      );
      _sessionBloc = MeasurementSessionBloc(
        repository: _repository,
        gatewayBloc: _gatewayBloc,
        httpClient: _httpClient,
        localDeviceId: _localDeviceId,
      );

      // Listen to session status changes - dispatch events instead of calling emit
      _sessionSubscription = _sessionBloc!.stream.listen((sessionState) {
        debugPrint(
          '[MeasurementPageBloc] Session state changed: status=${sessionState.status}, phase=${sessionState.phase}, error=${sessionState.error}',
        );
        add(_SessionStateChanged(sessionState: sessionState));
      });

      // Create the measurement session
      debugPrint(
        '[MeasurementPageBloc] Adding MeasurementSessionCreated event',
      );
      debugPrint(
        '[MeasurementPageBloc] Using profile: ${state.measurementProfile.id} '
        '(${state.measurementProfile.sweepFStart}Hz - ${state.measurementProfile.sweepFEnd}Hz)',
      );
      _sessionBloc!.add(
        MeasurementSessionCreated(
          jobId: event.jobId,
          lobbyId: state.lobbyId,
          speakers: speakers,
          microphones: microphones,
          sweepFStart: state.measurementProfile.sweepFStart,
          sweepFEnd: state.measurementProfile.sweepFEnd,
        ),
      );

      // Wait for session creation then start
      debugPrint('[MeasurementPageBloc] Waiting 500ms for session creation...');
      await Future.delayed(const Duration(milliseconds: 500));

      emit(state.copyWith(sweepStatus: SweepStatus.running));

      // Start the first speaker measurement
      debugPrint('[MeasurementPageBloc] Starting first speaker measurement');
      _sessionBloc!.add(const MeasurementSessionStartSpeaker());
    } catch (e, stackTrace) {
      debugPrint('[MeasurementPageBloc] ERROR in _onJobCreated: $e');
      debugPrint('[MeasurementPageBloc] Stack trace: $stackTrace');
      emit(
        state.copyWith(
          sweepStatus: SweepStatus.failed,
          sweepError: e.toString(),
        ),
      );
    }
  }

  /// Handles measurement start notification for non-admin (microphone) devices.
  ///
  /// When the admin starts a measurement, all devices receive a
  /// measurement.start_measurement event. Non-admin devices create their
  /// own MeasurementSessionBloc to participate in the measurement.
  Future<void> _onMeasurementStartReceived(
    _MeasurementStartReceived event,
    Emitter<MeasurementPageState> emit,
  ) async {
    debugPrint(
      '[MeasurementPageBloc] _onMeasurementStartReceived: '
      'sessionId=${event.sessionId}, jobId=${event.jobId}, '
      'speakerDeviceId=${event.speakerDeviceId}, speakerSlotId=${event.speakerSlotId}',
    );

    // Skip if we already have a session bloc (we're the admin)
    if (_sessionBloc != null) {
      debugPrint('[MeasurementPageBloc] Already have session bloc, skipping');
      return;
    }

    // Skip if this device is the speaker being measured
    if (event.speakerDeviceId == _localDeviceId) {
      debugPrint(
        '[MeasurementPageBloc] We are the speaker device, session will be '
        'managed by admin on this device',
      );
      return;
    }

    // Check if this device is a microphone (should participate in recording)
    final localDevice = state.devices.firstWhere(
      (d) => d.id == _localDeviceId,
      orElse: () => MeasurementDevice(
        id: _localDeviceId,
        name: 'Local',
        role: MeasurementDeviceRole.none,
        isLocal: true,
        isReady: false,
        latencyMs: 0,
        batteryLevel: 1.0,
      ),
    );

    debugPrint(
      '[MeasurementPageBloc] Local device role: ${localDevice.role}, '
      'slotId: ${localDevice.roleSlotId}',
    );

    if (localDevice.role != MeasurementDeviceRole.microphone) {
      debugPrint(
        '[MeasurementPageBloc] We are not a microphone, skipping measurement',
      );
      return;
    }

    // Create session bloc for this microphone device
    debugPrint(
      '[MeasurementPageBloc] Creating MeasurementSessionBloc for microphone device',
    );

    emit(state.copyWith(jobId: event.jobId, sweepStatus: SweepStatus.running));

    _sessionBloc = MeasurementSessionBloc(
      repository: _repository,
      gatewayBloc: _gatewayBloc,
      httpClient: _httpClient,
      localDeviceId: _localDeviceId,
    );

    // Listen to session status changes - dispatch events instead of calling emit
    _sessionSubscription = _sessionBloc!.stream.listen((sessionState) {
      debugPrint(
        '[MeasurementPageBloc] [Microphone] Session state changed: '
        'status=${sessionState.status}, phase=${sessionState.phase}, '
        'error=${sessionState.error}',
      );
      add(_SessionStateChanged(sessionState: sessionState));
    });

    // Join the existing session as a microphone
    debugPrint(
      '[MeasurementPageBloc] Joining measurement session as microphone',
    );
    _sessionBloc!.add(
      MeasurementSessionJoined(
        sessionId: event.sessionId,
        jobId: event.jobId,
        speakerSlotId: event.speakerSlotId,
      ),
    );
  }

  /// Handles session state changes from the MeasurementSessionBloc.
  void _onSessionStateChanged(
    _SessionStateChanged event,
    Emitter<MeasurementPageState> emit,
  ) {
    final sessionState = event.sessionState;

    // Capture audioHash when available
    if (sessionState.audioHash != null && state.audioHash == null) {
      emit(state.copyWith(audioHash: sessionState.audioHash));
    }

    if (sessionState.phase == MeasurementPhase.playing) {
      emit(state.copyWith(playbackPhase: PlaybackPhase.measurementPlaying));
    } else if (sessionState.phase != MeasurementPhase.playing &&
        state.playbackPhase != PlaybackPhase.idle) {
      emit(state.copyWith(playbackPhase: PlaybackPhase.idle));
    }

    if (sessionState.status == MeasurementSessionStatus.completed) {
      // Session completed (recordings uploaded), now request analysis
      debugPrint(
        '[MeasurementPageBloc] Session completed, requesting analysis...',
      );
      debugPrint('[MeasurementPageBloc] audioHash: ${state.audioHash}');
      emit(
        state.copyWith(
          sweepStatus: SweepStatus.requestingAnalysis,
          playbackPhase: PlaybackPhase.idle,
        ),
      );
      _cleanupSessionBloc();
      // Request analysis from backend
      add(const _AnalysisRequested());
    } else if (sessionState.status == MeasurementSessionStatus.error ||
        sessionState.status == MeasurementSessionStatus.cancelled) {
      emit(
        state.copyWith(
          sweepStatus: SweepStatus.failed,
          sweepError: sessionState.error,
          playbackPhase: PlaybackPhase.idle,
        ),
      );
      _cleanupSessionBloc();
    }
  }

  void _cleanupSessionBloc() {
    _sessionSubscription?.cancel();
    _sessionBloc?.close();
    _sessionBloc = null;
    _sessionSubscription = null;
  }

  Future<void> _onSweepCancelled(
    MeasurementSweepCancelled event,
    Emitter<MeasurementPageState> emit,
  ) async {
    _sessionBloc?.add(const MeasurementSessionCancelled());
    _cleanupSessionBloc();

    emit(
      state.copyWith(
        sweepStatus: SweepStatus.idle,
        sweepError: null,
        playbackPhase: PlaybackPhase.idle,
      ),
    );
  }

  /// Requests analysis from the backend after recordings are uploaded.
  Future<void> _onAnalysisRequested(
    _AnalysisRequested event,
    Emitter<MeasurementPageState> emit,
  ) async {
    if (state.jobId == null) {
      debugPrint('[MeasurementPageBloc] ERROR: No job ID for analysis');
      add(const _AnalysisFailed(error: 'No job ID available'));
      return;
    }

    debugPrint(
      '[MeasurementPageBloc] Requesting analysis for job ${state.jobId}',
    );

    try {
      final requestId = _generateRequestId();
      final responseFuture = _waitForResponse(requestId);

      // Request sweep deconvolution analysis using regenerated sweep
      // The backend will regenerate the exact sweep signal used during measurement
      final payload = {
        'event': 'analysis.run',
        'request_id': requestId,
        'data': {
          'job_id': state.jobId,
          'source': 'sweep_deconvolution_generated',
          // Use the recording uploaded by microphone
          'recording_upload': _findRecordingUploadName(),
          // audio_hash identifies the exact measurement signal for alignment
          if (state.audioHash != null) 'audio_hash': state.audioHash,
        },
      };

      debugPrint('[MeasurementPageBloc] Sending analysis.run: $payload');
      await _repository.sendJson(payload);

      debugPrint('[MeasurementPageBloc] Waiting for analysis response...');
      final response = await responseFuture;

      if (response.error != null) {
        debugPrint('[MeasurementPageBloc] Analysis failed: ${response.error}');
        add(_AnalysisFailed(error: response.error.toString()));
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final resultsData = data['results'] as Map<String, dynamic>?;

      if (resultsData == null) {
        debugPrint('[MeasurementPageBloc] No results in analysis response');
        add(const _AnalysisFailed(error: 'No results returned from analysis'));
        return;
      }

      debugPrint(
        '[MeasurementPageBloc] Analysis results received: $resultsData',
      );
      final results = AnalysisResults.fromJson(resultsData);
      add(_AnalysisResultsReceived(results: results));
    } catch (e, stackTrace) {
      debugPrint('[MeasurementPageBloc] ERROR in analysis request: $e');
      debugPrint('[MeasurementPageBloc] Stack trace: $stackTrace');
      add(_AnalysisFailed(error: e.toString()));
    }
  }

  /// Returns the recording upload name based on device/speaker configuration.
  String _findRecordingUploadName() {
    // Get the first microphone device to determine the upload name pattern
    final micDevice = state.devices.firstWhere(
      (d) => d.role == MeasurementDeviceRole.microphone,
      orElse: () => state.devices.first,
    );

    final speakerDevice = state.devices.firstWhere(
      (d) => d.role == MeasurementDeviceRole.loudspeaker,
      orElse: () => state.devices.first,
    );

    // Recording naming pattern from measurement_session_bloc.dart:
    // 'recording_${_localDeviceId}_${event.speakerSlotId}.wav'
    return 'recording_${micDevice.id}_${speakerDevice.roleSlotId ?? 'speaker-1'}.wav';
  }

  /// Handles successful analysis results.
  void _onAnalysisResultsReceived(
    _AnalysisResultsReceived event,
    Emitter<MeasurementPageState> emit,
  ) {
    debugPrint('[NAV_DEBUG] _onAnalysisResultsReceived called');
    debugPrint(
      '[MeasurementPageBloc] Analysis complete - RT60: ${event.results.rt.rt60}s, '
      'STI: ${event.results.sti}',
    );

    // Advance to results step (step 6 - "Review impulse results")
    debugPrint('[NAV_DEBUG] About to add MeasurementTimelineAdvanced event');
    add(const MeasurementTimelineAdvanced());

    debugPrint('[NAV_DEBUG] About to emit completed state with results');
    emit(
      state.copyWith(
        sweepStatus: SweepStatus.completed,
        analysisResults: event.results,
      ),
    );
    debugPrint(
      '[NAV_DEBUG] Completed state emitted, sweepStatus should be completed',
    );
  }

  /// Handles analysis failure.
  void _onAnalysisFailed(
    _AnalysisFailed event,
    Emitter<MeasurementPageState> emit,
  ) {
    debugPrint('[NAV_DEBUG] _onAnalysisFailed called: ${event.error}');
    debugPrint('[MeasurementPageBloc] Analysis failed: ${event.error}');

    emit(
      state.copyWith(
        sweepStatus: SweepStatus.failed,
        sweepError: 'Analysis failed: ${event.error}',
      ),
    );
  }

  /// Get the current measurement session BLoC for UI access.
  MeasurementSessionBloc? get sessionBloc => _sessionBloc;
}
