import 'dart:async';

import 'package:backend_gateway/backend_gateway.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:recording_service/recording_service.dart';

import '../models/measurement_session_models.dart';
import '../services/audio_playback_service.dart';
import '../services/measurement_audio_service.dart';

part 'measurement_session_event.dart';
part 'measurement_session_state.dart';

/// BLoC for coordinating measurement sessions.
///
/// Handles the synchronization protocol between speaker and microphone clients:
/// 1. Create session and notify clients to prepare
/// 2. Wait for all clients to signal ready
/// 3. Signal speaker to start playback
/// 4. Handle speaker finished signal
/// 5. Collect recordings from microphones
/// 6. Repeat for each speaker
class MeasurementSessionBloc
    extends Bloc<MeasurementSessionEvent, MeasurementSessionState> {
  MeasurementSessionBloc({
    required GatewayConnectionRepository repository,
    required GatewayConnectionBloc gatewayBloc,
    required String measurementServiceUrl,
    required String localDeviceId,
    RecordingService? recordingService,
  }) : _repository = repository,
       _gatewayBloc = gatewayBloc,
       _measurementServiceUrl = measurementServiceUrl,
       _localDeviceId = localDeviceId,
       _recordingService = recordingService ?? createRecordingService(),
       _audioService = MeasurementAudioService(baseUrl: measurementServiceUrl),
       _playbackService = AudioPlaybackService(),
       super(const MeasurementSessionState()) {
    // Event handlers
    on<MeasurementSessionCreated>(_onSessionCreated);
    on<MeasurementSessionStartSpeaker>(_onStartSpeaker);
    on<MeasurementSessionClientReady>(_onClientReady);
    on<MeasurementSessionSpeakerFinished>(_onSpeakerFinished);
    on<MeasurementSessionRecordingUploaded>(_onRecordingUploaded);
    on<MeasurementSessionCancelled>(_onSessionCancelled);
    on<MeasurementSessionReset>(_onSessionReset);

    // Internal events from gateway
    on<_MeasurementPrepareRecording>(_onPrepareRecording);
    on<_MeasurementPreparePlayback>(_onPreparePlayback);
    on<_MeasurementStartPlayback>(_onStartPlayback);
    on<_MeasurementStartRecording>(_onStartRecording);
    on<_MeasurementStopRecording>(_onStopRecording);
    on<_MeasurementSessionComplete>(_onSessionComplete);

    // Subscribe to gateway events
    _gatewaySubscription = _gatewayBloc.envelopes.listen(_handleGatewayEvent);
  }

  final GatewayConnectionRepository _repository;
  final GatewayConnectionBloc _gatewayBloc;
  final String _measurementServiceUrl;
  final String _localDeviceId;
  final RecordingService _recordingService;
  final MeasurementAudioService _audioService;
  final AudioPlaybackService _playbackService;
  StreamSubscription<GatewayEnvelope>? _gatewaySubscription;

  String? _currentRecordingPath;

  void _handleGatewayEvent(GatewayEnvelope envelope) {
    if (!envelope.isEvent) return;

    final data = envelope.data as Map<String, dynamic>? ?? {};
    debugPrint(
      '[MeasurementSessionBloc] Received gateway event: ${envelope.event}',
    );
    debugPrint('[MeasurementSessionBloc] Event data: $data');

    switch (envelope.event) {
      case 'measurement.prepare_recording':
        debugPrint(
          '[MeasurementSessionBloc] Processing prepare_recording event',
        );
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
        debugPrint(
          '[MeasurementSessionBloc] Processing prepare_playback event',
        );
        debugPrint(
          '[MeasurementSessionBloc] audio_file_endpoint: ${data['audio_file_endpoint']}',
        );
        add(
          _MeasurementPreparePlayback(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String,
            audioFileEndpoint: data['audio_file_endpoint'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
          ),
        );
        break;

      case 'measurement.start_playback':
        debugPrint('[MeasurementSessionBloc] Processing start_playback event');
        // This event goes to both speakers AND microphones
        // Speaker starts playing, microphones start recording
        add(
          _MeasurementStartPlayback(
            sessionId: data['session_id'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
          ),
        );
        add(
          _MeasurementStartRecording(
            sessionId: data['session_id'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
          ),
        );
        break;

      case 'measurement.stop_recording':
        debugPrint('[MeasurementSessionBloc] Processing stop_recording event');
        add(
          _MeasurementStopRecording(
            sessionId: data['session_id'] as String,
            jobId: data['job_id'] as String,
            speakerSlotId: data['speaker_slot_id'] as String,
            uploadEndpoint: data['upload_endpoint'] as String,
          ),
        );
        break;

      case 'measurement.session_complete':
        debugPrint(
          '[MeasurementSessionBloc] Processing session_complete event',
        );
        add(
          _MeasurementSessionComplete(
            sessionId: data['session_id'] as String,
            completedSpeakers: List<String>.from(
              data['completed_speakers'] ?? [],
            ),
          ),
        );
        break;

      case 'measurement.session_cancelled':
        debugPrint(
          '[MeasurementSessionBloc] Processing session_cancelled event',
        );
        add(const MeasurementSessionCancelled());
        break;

      default:
        debugPrint('[MeasurementSessionBloc] Unknown event: ${envelope.event}');
    }
  }

  Future<void> _onSessionCreated(
    MeasurementSessionCreated event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    debugPrint(
      '[MeasurementSessionBloc] _onSessionCreated: jobId=${event.jobId}, lobbyId=${event.lobbyId}',
    );
    debugPrint(
      '[MeasurementSessionBloc] speakers=${event.speakers.map((s) => s.deviceId).toList()}',
    );
    debugPrint(
      '[MeasurementSessionBloc] microphones=${event.microphones.map((m) => m.deviceId).toList()}',
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
      debugPrint('[MeasurementSessionBloc] Sending create_session: $payload');

      await _repository.sendJson(payload);

      debugPrint(
        '[MeasurementSessionBloc] Waiting for create_session response...',
      );
      final response = await responseFuture;
      debugPrint(
        '[MeasurementSessionBloc] Received response: data=${response.data}, error=${response.error}',
      );

      if (response.error != null) {
        throw Exception('Failed to create session: ${response.error}');
      }

      final data = response.data as Map<String, dynamic>;
      final sessionInfo = MeasurementSessionInfo(
        sessionId: data['session_id'] as String,
        jobId: event.jobId,
        lobbyId: event.lobbyId,
        speakers: event.speakers,
        microphones: event.microphones,
        audioDurationSeconds: (data['audio_duration_seconds'] as num)
            .toDouble(),
      );

      debugPrint(
        '[MeasurementSessionBloc] Session created: sessionId=${sessionInfo.sessionId}, audioDuration=${sessionInfo.audioDurationSeconds}s',
      );

      emit(
        state.copyWith(
          status: MeasurementSessionStatus.created,
          sessionInfo: sessionInfo,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[MeasurementSessionBloc] ERROR in _onSessionCreated: $e');
      debugPrint('[MeasurementSessionBloc] Stack trace: $stackTrace');
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStartSpeaker(
    MeasurementSessionStartSpeaker event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    debugPrint(
      '[MeasurementSessionBloc] _onStartSpeaker called, sessionInfo=$session',
    );

    if (session == null) {
      debugPrint('[MeasurementSessionBloc] ERROR: No session info available');
      return;
    }

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.preparing,
      ),
    );

    try {
      final requestId = _generateRequestId();
      final responseFuture = _waitForResponse(requestId);

      final payload = {
        'event': 'measurement.start_speaker',
        'request_id': requestId,
        'data': {'session_id': session.sessionId},
      };
      debugPrint('[MeasurementSessionBloc] Sending start_speaker: $payload');

      await _repository.sendJson(payload);

      debugPrint(
        '[MeasurementSessionBloc] Waiting for start_speaker response...',
      );
      final response = await responseFuture;
      debugPrint(
        '[MeasurementSessionBloc] Received response: data=${response.data}, error=${response.error}',
      );

      if (response.error != null) {
        throw Exception('Failed to start speaker: ${response.error}');
      }

      debugPrint(
        '[MeasurementSessionBloc] Start speaker succeeded, now waiting for ready signals',
      );
      emit(state.copyWith(phase: MeasurementPhase.waitingReady));
    } catch (e, stackTrace) {
      debugPrint('[MeasurementSessionBloc] ERROR in _onStartSpeaker: $e');
      debugPrint('[MeasurementSessionBloc] Stack trace: $stackTrace');
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onClientReady(
    MeasurementSessionClientReady event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

    try {
      final requestId = _generateRequestId();
      await _repository.sendJson({
        'event': 'measurement.client_ready',
        'request_id': requestId,
        'data': {'session_id': session.sessionId},
      });

      emit(state.copyWith(isLocalReady: true));
    } catch (e) {
      debugPrint('Failed to send client ready: $e');
    }
  }

  Future<void> _onSpeakerFinished(
    MeasurementSessionSpeakerFinished event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

    try {
      final requestId = _generateRequestId();
      await _repository.sendJson({
        'event': 'measurement.speaker_finished',
        'request_id': requestId,
        'data': {'session_id': session.sessionId},
      });

      emit(state.copyWith(phase: MeasurementPhase.recordingComplete));
    } catch (e) {
      debugPrint('Failed to send speaker finished: $e');
    }
  }

  Future<void> _onRecordingUploaded(
    MeasurementSessionRecordingUploaded event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    final session = state.sessionInfo;
    if (session == null) return;

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
    } catch (e) {
      debugPrint('Failed to send recording uploaded: $e');
    }
  }

  Future<void> _onSessionCancelled(
    MeasurementSessionCancelled event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    // Stop any ongoing playback or recording
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
    await _playbackService.stop();
    if (await _recordingService.isRecording()) {
      await _recordingService.cancel();
    }

    emit(const MeasurementSessionState());
  }

  // ============================================================
  // Internal event handlers (from gateway)
  // ============================================================

  Future<void> _onPrepareRecording(
    _MeasurementPrepareRecording event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    debugPrint('Preparing for recording: session=${event.sessionId}');

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.preparing,
        localRole: LocalMeasurementRole.microphone,
        isLocalReady: false,
      ),
    );

    try {
      // Ensure we have microphone permission
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      // Prepare recording path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath =
          '/tmp/recording_${event.sessionId}_$timestamp.wav';

      // Signal ready
      add(const MeasurementSessionClientReady());
    } catch (e) {
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
    debugPrint(
      '[MeasurementSessionBloc] _onPreparePlayback: session=${event.sessionId}, endpoint=${event.audioFileEndpoint}',
    );
    debugPrint(
      '[MeasurementSessionBloc] measurementServiceUrl=$_measurementServiceUrl',
    );

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.preparingMeasurement,
        phase: MeasurementPhase.preparing,
        localRole: LocalMeasurementRole.speaker,
        isLocalReady: false,
      ),
    );

    try {
      // Download the measurement audio
      debugPrint('[MeasurementSessionBloc] Downloading measurement audio...');
      final audioPath = await _playbackService.downloadMeasurementAudio(
        baseUrl: _measurementServiceUrl,
        sessionId: event.sessionId,
      );
      debugPrint('[MeasurementSessionBloc] Audio downloaded to: $audioPath');

      // Prepare the player
      debugPrint('[MeasurementSessionBloc] Preparing audio player...');
      await _playbackService.prepare();
      debugPrint('[MeasurementSessionBloc] Audio player prepared successfully');

      // Signal ready
      debugPrint('[MeasurementSessionBloc] Signaling client ready');
      add(const MeasurementSessionClientReady());
    } catch (e, stackTrace) {
      debugPrint('[MeasurementSessionBloc] ERROR in _onPreparePlayback: $e');
      debugPrint('[MeasurementSessionBloc] Stack trace: $stackTrace');
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

    debugPrint('Starting playback: session=${event.sessionId}');

    emit(state.copyWith(phase: MeasurementPhase.playing));

    try {
      // For the speaker, we start playback
      await _playbackService.play();

      // Playback finished
      add(const MeasurementSessionSpeakerFinished());
    } catch (e) {
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

    debugPrint('Starting recording: session=${event.sessionId}');

    emit(state.copyWith(phase: MeasurementPhase.playing));

    try {
      // Start recording with the prepared path
      if (_currentRecordingPath == null) {
        throw Exception('Recording path not prepared');
      }
      await _recordingService.start(filePath: _currentRecordingPath!);
      debugPrint('Recording started at: $_currentRecordingPath');
    } catch (e) {
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

    debugPrint('Stopping recording and uploading: session=${event.sessionId}');

    emit(state.copyWith(phase: MeasurementPhase.recordingComplete));

    try {
      // Stop the recording
      final recordingPath = await _recordingService.stop();
      if (recordingPath == null) {
        throw Exception('Recording failed - no file produced');
      }

      // Generate upload name
      final uploadName =
          'recording_${_localDeviceId}_${event.speakerSlotId}.wav';

      // Upload the recording
      await _audioService.uploadRecording(
        jobId: event.jobId,
        uploadName: uploadName,
        filePath: recordingPath,
      );

      // Notify server
      add(MeasurementSessionRecordingUploaded(uploadName: uploadName));

      emit(state.copyWith(phase: MeasurementPhase.processing));
    } catch (e) {
      emit(
        state.copyWith(
          status: MeasurementSessionStatus.error,
          phase: MeasurementPhase.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSessionComplete(
    _MeasurementSessionComplete event,
    Emitter<MeasurementSessionState> emit,
  ) async {
    debugPrint('Session complete: ${event.completedSpeakers}');

    emit(
      state.copyWith(
        status: MeasurementSessionStatus.completed,
        phase: MeasurementPhase.completed,
        localRole: LocalMeasurementRole.none,
      ),
    );
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
    await _gatewaySubscription?.cancel();
    await _playbackService.dispose();
    await _recordingService.dispose();
    _audioService.dispose();
    return super.close();
  }
}
