import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recording_service/recording_service.dart';

import '../../backend_http_client.dart';
import '../../bloc/gateway_connection_bloc.dart';
import '../../gateway_connection_repository.dart';
import '../../gateway_envelope.dart';
import '../models/measurement_session_models.dart';
import '../services/audio_playback_service.dart';
import '../services/measurement_audio_service.dart';
import '../services/measurement_debug_logger.dart';

part 'measurement_session_event.dart';
part 'measurement_session_state.dart';

/// BLoC for coordinating measurement sessions using the new 11-step protocol:
///
/// 1. Lobby creator tells backend measurements should start
/// 2. Server tells all clients that measurement will start now
/// 3. All clients send a ready signal
/// 4. Speaker requests the audiofile + hash
/// 5. Backend sends speaker audiofile (.wav) with hash for verification
/// 6. Speaker tells backend it received working audiofile, ready to start
/// 7. Backend tells all microphones to start recording now
/// 8. Microphones start recording and confirm to backend
/// 9. Backend tells loudspeaker to start playing audiofile
/// 10. Speaker plays, when finished tells backend
/// 11. Backend tells microphones to stop, they send recordings to backend
class MeasurementSessionBloc
    extends Bloc<MeasurementSessionEvent, MeasurementSessionState> {
  MeasurementSessionBloc({
    required GatewayConnectionRepository repository,
    required GatewayConnectionBloc gatewayBloc,
    required BackendHttpClient httpClient,
    required String localDeviceId,
    RecordingService? recordingService,
  }) : _repository = repository,
       _gatewayBloc = gatewayBloc,
       _httpClient = httpClient,
       _localDeviceId = localDeviceId,
       _recordingService = recordingService ?? createRecordingService(),
       _audioService = MeasurementAudioService(httpClient: httpClient),
       _playbackService = AudioPlaybackService(),
       _log = MeasurementDebugLogger.instance,
       super(const MeasurementSessionState()) {
    _log.info(
      _tag,
      'MeasurementSessionBloc initialized',
      data: {
        'backendHttpBaseUrl': httpClient.baseUrl,
        'localDeviceId': localDeviceId,
      },
    );

    // Event handlers
    on<MeasurementSessionCreated>(_onSessionCreated);
    on<MeasurementSessionJoined>(_onSessionJoined);
    on<MeasurementSessionStartSpeaker>(_onStartSpeaker);
    on<MeasurementSessionClientReady>(_onClientReady);
    on<MeasurementSessionSpeakerFinished>(_onSpeakerFinished);
    on<MeasurementSessionRecordingUploaded>(_onRecordingUploaded);
    on<MeasurementSessionCancelled>(_onSessionCancelled);
    on<MeasurementSessionReset>(_onSessionReset);

    // Internal events from gateway - new protocol
    on<_MeasurementStartNotification>(_onMeasurementStartNotification);
    on<_MeasurementRequestAudio>(_onRequestAudio);
    on<_MeasurementAudioReady>(_onAudioReady);
    on<_MeasurementStartRecordingCommand>(_onStartRecordingCommand);
    on<_MeasurementRecordingStarted>(_onRecordingStarted);
    on<_MeasurementStartPlaybackCommand>(_onStartPlaybackCommand);
    on<_MeasurementStopRecordingCommand>(_onStopRecordingCommand);
    on<_MeasurementSessionComplete>(_onSessionComplete);

    // Legacy events for backward compatibility
    on<_MeasurementPrepareRecording>(_onPrepareRecording);
    on<_MeasurementPreparePlayback>(_onPreparePlayback);
    on<_MeasurementStartPlayback>(_onStartPlayback);
    on<_MeasurementStartRecording>(_onStartRecording);
    on<_MeasurementStopRecording>(_onStopRecording);

    // Subscribe to gateway events
    _gatewaySubscription = _gatewayBloc.envelopes.listen(_handleGatewayEvent);
    _log.debug(_tag, 'Subscribed to gateway events');
  }

  static const String _tag = 'SessionBloc';

  final GatewayConnectionRepository _repository;
  final GatewayConnectionBloc _gatewayBloc;
  final BackendHttpClient _httpClient;
  final String _localDeviceId;
  final RecordingService _recordingService;
  final MeasurementAudioService _audioService;
  final AudioPlaybackService _playbackService;
  final MeasurementDebugLogger _log;
  StreamSubscription<GatewayEnvelope>? _gatewaySubscription;

  String? _currentRecordingPath;

  void _handleGatewayEvent(GatewayEnvelope envelope) {
    if (!envelope.isEvent) return;

    final data = envelope.data as Map<String, dynamic>? ?? {};
    _log.debug(_tag, 'Received gateway event: ${envelope.event}', data: data);

    switch (envelope.event) {
      // New protocol events
      case 'measurement.start_measurement':
        _log.info(_tag, 'Step 2: Server notified measurement will start');
        add(
          _MeasurementStartNotification(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String? ?? state.sessionInfo?.jobId ?? '',
          ),
        );
        break;

      case 'measurement.request_audio':
        _log.info(_tag, 'Step 4: Server requesting speaker to get audio');
        add(
          _MeasurementRequestAudio(
            sessionId: data['session_id'] as String,
            audioEndpoint:
                data['audio_url'] as String? ??
                data['audio_endpoint'] as String? ??
                '',
            expectedHash: data['expected_hash'] as String?,
          ),
        );
        break;

      case 'measurement.start_recording':
        _log.info(_tag, 'Step 7: Server commanding microphones to record');
        add(
          _MeasurementStartRecordingCommand(
            sessionId: data['session_id'] as String,
            jobId: state.sessionInfo?.jobId ?? '',
            speakerSlotId: data['speaker_slot_id'] as String,
          ),
        );
        break;

      case 'measurement.start_playback':
        _log.info(_tag, 'Step 9: Server commanding speaker to play');
        add(
          _MeasurementStartPlaybackCommand(
            sessionId: data['session_id'] as String,
            speakerSlotId: data['speaker_slot_id'] as String? ?? '',
          ),
        );
        break;

      case 'measurement.stop_recording':
        _log.info(_tag, 'Step 10: Server commanding microphones to stop');
        add(
          _MeasurementStopRecordingCommand(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String? ?? state.sessionInfo?.jobId ?? '',
            speakerSlotId: data['speaker_slot_id'] as String,
            uploadEndpoint: data['upload_endpoint'] as String,
          ),
        );
        break;

      // Legacy protocol events (backward compatibility)
      case 'measurement.prepare_recording':
        _log.info(_tag, 'Legacy: prepare_recording event');
        add(
          _MeasurementPrepareRecording(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
            expectedDuration: (data['expected_duration_seconds'] as num)
                .toDouble(),
          ),
        );
        break;

      case 'measurement.prepare_playback':
        _log.info(_tag, 'Legacy: prepare_playback event');
        add(
          _MeasurementPreparePlayback(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String,
            audioFileEndpoint: data['audio_file_endpoint'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
          ),
        );
        break;

      case 'measurement.session_complete':
        _log.info(_tag, 'Session complete event');
        add(
          _MeasurementSessionComplete(
            sessionId: data['session_id'] as String,
            completedSpeakers: List<String>.from(
              data['completed_speakers'] ?? [],
            ),
          ),
        );
        break;

      case 'measurement.speaker_complete':
        _log.info(
          _tag,
          'Speaker measurement complete',
          data: {
            'completedSlotId': data['completed_speaker_slot_id'],
            'remainingSpeakers': data['remaining_speakers'],
          },
        );
        // TODO: Handle next speaker if remaining_speakers > 0
        break;

      case 'measurement.session_cancelled':
        _log.warning(
          _tag,
          'Session cancelled by server',
          data: {'reason': data['reason']},
        );
        add(const MeasurementSessionCancelled());
        break;

      case 'measurement.error':
        _log.error(
          _tag,
          'Error event from server',
          data: {
            'errorDeviceId': data['error_device_id'],
            'errorMessage': data['error_message'],
            'errorCode': data['error_code'],
          },
        );
        // For now, cancel the session on errors
        add(const MeasurementSessionCancelled());
        break;

      default:
        _log.debug(_tag, 'Unhandled event: ${envelope.event}');
    }
  }

  Future<void> _onSessionCreated(
    MeasurementSessionCreated event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Creating measurement session',
      data: {
        'jobId': event.jobId,
        'lobbyId': event.lobbyId,
        'speakerCount': event.speakers.length,
        'microphoneCount': event.microphones.length,
      },
    );

    emit(
      state.copyWith(status: MeasurementSessionStatus.creating, error: null),
    );

    try {
      final requestId = _generateRequestId();
      final responseFuture = _waitForResponse(requestId);

      final payload = {
        'event': 'measurement.create_session',
        'request_id': requestId,
        'data': {
          'job_id': event.jobId,
          'lobby_id': event.lobbyId,
          'speakers': event.speakers
              .map(
                (s) => {
                  'device_id': s.deviceId,
                  'slot_id': s.slotId,
                  'slot_label': s.slotLabel,
                },
              )
              .toList(),
          'microphones': event.microphones
              .map(
                (m) => {
                  'device_id': m.deviceId,
                  'slot_id': m.slotId,
                  'slot_label': m.slotLabel,
                },
              )
              .toList(),
        },
      };

      _log.debug(_tag, 'Sending create_session request', data: payload);
      await _repository.sendJson(payload);

      _log.debug(_tag, 'Waiting for create_session response...');
      final response = await responseFuture;

      if (response.error != null) {
        _log.error(
          _tag,
          'Failed to create session',
          data: {'error': response.error},
        );
        throw Exception('Failed to create session: ${response.error}');
      }

      final data = response.data as Map<String, dynamic>;
      final sessionInfo = MeasurementSessionInfo(
        sessionId: data['session_id'] as String,
        jobId: event.jobId,
        lobbyId: event.lobbyId,
        speakers: event.speakers,
        microphones: event.microphones,
        audioDurationSeconds:
            (data['audio_duration_seconds'] as num?)?.toDouble() ?? 15.0,
        sweepFStart: event.sweepFStart,
        sweepFEnd: event.sweepFEnd,
      );

      _log.info(
        _tag,
        'Session created successfully',
        data: {
          'sessionId': sessionInfo.sessionId,
          'audioDuration': sessionInfo.audioDurationSeconds,
        },
      );

      emit(
        state.copyWith(
          status: MeasurementSessionStatus.created,
          sessionInfo: sessionInfo,
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Error creating session',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  /// Handler for non-admin devices joining an existing measurement session.
  /// This is called when a microphone device receives measurement.start_measurement.
  Future<void> _onSessionJoined(
    MeasurementSessionJoined event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Joining existing measurement session as microphone',
      data: {
        'sessionId': event.sessionId,
        'jobId': event.jobId,
        'speakerSlotId': event.speakerSlotId,
        'localDeviceId': _localDeviceId,
      },
    );

    // Create minimal session info for microphone device
    final sessionInfo = MeasurementSessionInfo(
      sessionId: event.sessionId,
      jobId: event.jobId,
      lobbyId: '', // Not needed for microphone
      speakers: [], // Not needed for microphone
      microphones: [
        MicrophoneInfo(
          deviceId: _localDeviceId,
          slotId: '', // Will be filled later if needed
          slotLabel: '',
        ),
      ],
      audioDurationSeconds: 15.0, // Default
    );

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.created,
        sessionInfo: sessionInfo,
        phase: MeasurementPhase.waitingReady,
        isLocalReady: false,
      ),
    );

    // Step 3: Immediately send ready signal as microphone
    _log.info(_tag, 'Step 3: Microphone sending ready signal');
    add(const MeasurementSessionClientReady());
  }

  /// Step 1: Lobby creator initiates measurement start
  Future<void> _onStartSpeaker(
    MeasurementSessionStartSpeaker event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) {
      _log.error(_tag, 'Cannot start speaker - no session info');
      return;
    }

    _log.info(
      _tag,
      'Step 1: Initiating measurement start',
      data: {'sessionId': session.sessionId},
    );

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.initiating,
      ),
    );

    try {
      final requestId = _generateRequestId();
      final responseFuture = _waitForResponse(requestId);

      // Event name matches backend handler: measurement.start_speaker
      final payload = {
        'event': 'measurement.start_speaker',
        'request_id': requestId,
        'data': {'session_id': session.sessionId},
      };

      _log.debug(_tag, 'Sending start_speaker request', data: payload);
      await _repository.sendJson(payload);

      final response = await responseFuture;
      if (response.error != null) {
        _log.error(
          _tag,
          'Failed to start measurement',
          data: {'error': response.error},
        );
        throw Exception('Failed to start measurement: ${response.error}');
      }

      _log.info(_tag, 'Measurement start initiated, waiting for notifications');
      emit(state.copyWith(phase: MeasurementPhase.notifyingClients));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Error starting measurement',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  /// Step 2: Server notifies all clients measurement will start
  Future<void> _onMeasurementStartNotification(
    _MeasurementStartNotification event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Step 2: Received start notification',
      data: {'sessionId': event.sessionId},
    );

    emit(
      state.copyWith(phase: MeasurementPhase.waitingReady, isLocalReady: false),
    );

    // Step 3: Send ready signal
    _log.info(_tag, 'Step 3: Sending ready signal');
    add(const MeasurementSessionClientReady());
  }

  /// Step 3: Client sends ready signal
  Future<void> _onClientReady(
    MeasurementSessionClientReady event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) {
      _log.error(_tag, 'Cannot send ready - no session info');
      return;
    }

    _log.info(_tag, 'Step 3: Sending client ready signal');

    try {
      final requestId = _generateRequestId();
      // Event name matches backend handler: measurement.ready (also accepts measurement.client_ready)
      await _repository.sendJson({
        'event': 'measurement.ready',
        'request_id': requestId,
        'data': {'session_id': session.sessionId, 'device_id': _localDeviceId},
      });

      _log.debug(_tag, 'Ready signal sent');
      emit(state.copyWith(isLocalReady: true));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to send ready signal',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Step 4: Speaker receives request to download audio
  Future<void> _onRequestAudio(
    _MeasurementRequestAudio event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Step 4: Speaker requested to get audio',
      data: {
        'sessionId': event.sessionId,
        'audioEndpoint': event.audioEndpoint,
        'expectedHash': event.expectedHash,
      },
    );

    emit(
      state.copyWith(
        localRole: LocalMeasurementRole.speaker,
        phase: MeasurementPhase.requestingAudio,
      ),
    );

    try {
      // Step 5: Download and verify audio
      _log.info(_tag, 'Step 5: Downloading audio file');
      emit(state.copyWith(phase: MeasurementPhase.downloadingAudio));

      // Get sweep frequency parameters from session info
      final sweepFStart = state.sessionInfo?.sweepFStart ?? 20.0;
      final sweepFEnd = state.sessionInfo?.sweepFEnd ?? 20000.0;

      final audioPath = await _playbackService.downloadMeasurementAudio(
        httpClient: _httpClient,
        sessionId: event.sessionId,
        sweepFStart: sweepFStart,
        sweepFEnd: sweepFEnd,
      );

      // Capture the audio hash for later use in analysis
      final audioHash = _playbackService.audioHash;
      _log.info(
        _tag,
        'Audio downloaded',
        data: {'path': audioPath, 'audioHash': audioHash},
      );

      // Prepare the player
      await _playbackService.prepare();
      _log.debug(_tag, 'Audio player prepared');

      // Update state with audio hash
      emit(state.copyWith(audioHash: audioHash));

      // Step 6: Notify server that audio is ready
      _log.info(_tag, 'Step 6: Confirming audio ready to server');
      add(_MeasurementAudioReady(sessionId: event.sessionId));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to download/prepare audio',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  /// Step 6: Speaker confirms audio is ready
  Future<void> _onAudioReady(
    _MeasurementAudioReady event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

    _log.info(_tag, 'Step 6: Sending audio ready confirmation');

    emit(state.copyWith(phase: MeasurementPhase.speakerConfirmed));

    try {
      final requestId = _generateRequestId();
      await _repository.sendJson({
        'event': 'measurement.speaker_audio_ready',
        'request_id': requestId,
        'data': {'session_id': event.sessionId, 'device_id': _localDeviceId},
      });
      _log.debug(_tag, 'Audio ready confirmation sent');
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to send audio ready',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Step 7: Server commands microphones to start recording
  Future<void> _onStartRecordingCommand(
    _MeasurementStartRecordingCommand event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Step 7: Received start recording command',
      data: {
        'sessionId': event.sessionId,
        'speakerSlotId': event.speakerSlotId,
      },
    );

    emit(
      state.copyWith(
        localRole: LocalMeasurementRole.microphone,
        phase: MeasurementPhase.startingRecording,
      ),
    );

    try {
      // Check permission
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        _log.warning(_tag, 'No microphone permission, requesting...');
        await _recordingService.requestPermission();
      }

      // Prepare recording path using app's cache directory (works on all platforms)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cacheDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${cacheDir.path}/recording_${event.sessionId}_$timestamp.wav';

      _log.debug(
        _tag,
        'Starting recording',
        data: {'path': _currentRecordingPath},
      );
      await _recordingService.start(filePath: _currentRecordingPath!);

      // Step 8: Confirm recording started
      _log.info(_tag, 'Step 8: Recording started, confirming to server');
      add(_MeasurementRecordingStarted(sessionId: event.sessionId));

      emit(state.copyWith(phase: MeasurementPhase.recording));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to start recording',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  /// Step 8: Microphone confirms recording started
  Future<void> _onRecordingStarted(
    _MeasurementRecordingStarted event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(_tag, 'Step 8: Sending recording started confirmation');

    try {
      final requestId = _generateRequestId();
      await _repository.sendJson({
        'event': 'measurement.recording_started',
        'request_id': requestId,
        'data': {'session_id': event.sessionId, 'device_id': _localDeviceId},
      });
      _log.debug(_tag, 'Recording started confirmation sent');
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to confirm recording started',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Step 9: Server commands speaker to start playback
  Future<void> _onStartPlaybackCommand(
    _MeasurementStartPlaybackCommand event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    if (state.localRole != LocalMeasurementRole.speaker) {
      _log.debug(_tag, 'Ignoring playback command - not a speaker');
      return;
    }

    _log.info(
      _tag,
      'Step 9: Starting audio playback',
      data: {
        'sessionId': event.sessionId,
        'speakerSlotId': event.speakerSlotId,
      },
    );

    emit(
      state.copyWith(
        phase: MeasurementPhase.playing,
        status: MeasurementSessionStatus.measuring,
      ),
    );

    try {
      await _playbackService.play();
      _log.info(_tag, 'Playback completed');

      // Step 10: Notify server playback finished
      add(const MeasurementSessionSpeakerFinished());
    } catch (e, stackTrace) {
      _log.error(_tag, 'Playback failed', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  /// Step 10: Speaker finished playback
  Future<void> _onSpeakerFinished(
    MeasurementSessionSpeakerFinished event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

    _log.info(_tag, 'Step 10: Speaker finished playback, notifying server');

    emit(state.copyWith(phase: MeasurementPhase.playbackComplete));

    try {
      final requestId = _generateRequestId();
      // Event name matches backend handler: measurement.playback_complete
      await _repository.sendJson({
        'event': 'measurement.playback_complete',
        'request_id': requestId,
        'data': {'session_id': session.sessionId},
      });
      _log.debug(_tag, 'Playback complete notification sent');
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to send playback complete',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Step 10 (microphone side): Server commands to stop recording
  Future<void> _onStopRecordingCommand(
    _MeasurementStopRecordingCommand event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    if (state.localRole != LocalMeasurementRole.microphone) {
      _log.debug(_tag, 'Ignoring stop recording command - not a microphone');
      return;
    }

    _log.info(
      _tag,
      'Step 10: Stopping recording',
      data: {'sessionId': event.sessionId},
    );

    emit(state.copyWith(phase: MeasurementPhase.uploadingRecordings));

    try {
      final recordingPath = await _recordingService.stop();
      if (recordingPath == null) {
        throw Exception('Recording failed - no file produced');
      }

      _log.info(_tag, 'Recording stopped', data: {'path': recordingPath});

      // Step 11: Upload recording
      _log.info(_tag, 'Step 11: Uploading recording');
      final uploadName =
          'recording_${_localDeviceId}_${event.speakerSlotId}.wav';

      await _audioService.uploadRecording(
        jobId: event.jobId,
        uploadName: uploadName,
        filePath: recordingPath,
      );

      _log.info(_tag, 'Recording uploaded', data: {'uploadName': uploadName});

      // Notify server
      add(MeasurementSessionRecordingUploaded(uploadName: uploadName));
      emit(state.copyWith(phase: MeasurementPhase.processing));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to stop/upload recording',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRecordingUploaded(
    MeasurementSessionRecordingUploaded event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

    _log.info(
      _tag,
      'Recording uploaded, notifying server',
      data: {'uploadName': event.uploadName},
    );

    try {
      final requestId = _generateRequestId();
      await _repository.sendJson({
        'event': 'measurement.recording_uploaded',
        'request_id': requestId,
        'data': {
          'session_id': session.sessionId,
          'upload_name': event.uploadName,
        },
      });
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Failed to notify upload',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onSessionCancelled(
    MeasurementSessionCancelled event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.warning(_tag, 'Session cancelled');

    await _playbackService.stop();
    if (await _recordingService.isRecording()) {
      await _recordingService.cancel();
    }

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.cancelled,
        phase: MeasurementPhase.failed,
        localRole: LocalMeasurementRole.none,
        isLocalReady: false,
      ),
    );
  }

  Future<void> _onSessionReset(
    MeasurementSessionReset event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(_tag, 'Session reset');

    await _playbackService.stop();
    if (await _recordingService.isRecording()) {
      await _recordingService.cancel();
    }

    emit(const MeasurementSessionState());
  }

  Future<void> _onSessionComplete(
    _MeasurementSessionComplete event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Session complete',
      data: {
        'sessionId': event.sessionId,
        'completedSpeakers': event.completedSpeakers,
      },
    );

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.completed,
        phase: MeasurementPhase.completed,
        localRole: LocalMeasurementRole.none,
      ),
    );
  }

  // ============================================================
  // Legacy event handlers (for backward compatibility)
  // ============================================================

  Future<void> _onPrepareRecording(
    _MeasurementPrepareRecording event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(_tag, 'Legacy: Preparing for recording');

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.waitingReady,
        localRole: LocalMeasurementRole.microphone,
        isLocalReady: false,
      ),
    );

    try {
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        _log.warning(_tag, 'No microphone permission');
        throw Exception('Microphone permission denied');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cacheDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${cacheDir.path}/recording_${event.sessionId}_$timestamp.wav';

      add(const MeasurementSessionClientReady());
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Prepare recording failed',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onPreparePlayback(
    _MeasurementPreparePlayback event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    _log.info(
      _tag,
      'Legacy: Preparing for playback',
      data: {'audioFileEndpoint': event.audioFileEndpoint},
    );

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.downloadingAudio,
        localRole: LocalMeasurementRole.speaker,
        isLocalReady: false,
      ),
    );

    try {
      final audioPath = await _playbackService.downloadMeasurementAudio(
        httpClient: _httpClient,
        sessionId: event.sessionId,
      );
      _log.debug(_tag, 'Audio downloaded to: $audioPath');

      await _playbackService.prepare();
      _log.debug(_tag, 'Audio player prepared');

      add(const MeasurementSessionClientReady());
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Prepare playback failed',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStartPlayback(
    _MeasurementStartPlayback event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    if (state.localRole != LocalMeasurementRole.speaker) return;

    _log.info(_tag, 'Legacy: Starting playback');

    emit(
      state.copyWith(
        phase: MeasurementPhase.playing,
        status: MeasurementSessionStatus.measuring,
      ),
    );

    try {
      await _playbackService.play();
      add(const MeasurementSessionSpeakerFinished());
    } catch (e, stackTrace) {
      _log.error(_tag, 'Playback failed', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStartRecording(
    _MeasurementStartRecording event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    if (state.localRole != LocalMeasurementRole.microphone) return;

    _log.info(_tag, 'Legacy: Starting recording');

    emit(state.copyWith(phase: MeasurementPhase.recording));

    try {
      if (_currentRecordingPath == null) {
        throw Exception('Recording path not prepared');
      }
      await _recordingService.start(filePath: _currentRecordingPath!);
      _log.debug(_tag, 'Recording started');
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Recording start failed',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStopRecording(
    _MeasurementStopRecording event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    if (state.localRole != LocalMeasurementRole.microphone) return;

    _log.info(_tag, 'Legacy: Stopping recording');

    emit(state.copyWith(phase: MeasurementPhase.uploadingRecordings));

    try {
      final recordingPath = await _recordingService.stop();
      if (recordingPath == null) {
        throw Exception('Recording failed - no file produced');
      }

      final uploadName =
          'recording_${_localDeviceId}_${event.speakerSlotId}.wav';

      await _audioService.uploadRecording(
        jobId: event.jobId,
        uploadName: uploadName,
        filePath: recordingPath,
      );

      add(MeasurementSessionRecordingUploaded(uploadName: uploadName));
      emit(state.copyWith(phase: MeasurementPhase.processing));
    } catch (e, stackTrace) {
      _log.error(
        _tag,
        'Stop recording failed',
        error: e,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  String _generateRequestId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<GatewayEnvelope> _waitForResponse(String requestId) {
    return _gatewayBloc.envelopes
        .firstWhere((e) => e.requestId == requestId)
        .timeout(const Duration(seconds: 30));
  }

  @override
  Future<void> close() async {
    _log.info(_tag, 'Closing MeasurementSessionBloc');
    await _gatewaySubscription?.cancel();
    await _playbackService.dispose();
    await _recordingService.dispose();
    _audioService.dispose();
    return super.close();
  }
}
