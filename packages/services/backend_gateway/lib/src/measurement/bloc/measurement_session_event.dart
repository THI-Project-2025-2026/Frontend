part of 'measurement_session_bloc.dart';

/// Base class for measurement session events.
sealed class MeasurementSessionEvent extends Equatable {
  const MeasurementSessionEvent();

  @override
  List<Object?> get props => [];
}

/// Create a new measurement session.
class MeasurementSessionCreated extends MeasurementSessionEvent {
  const MeasurementSessionCreated({
    required this.jobId,
    required this.lobbyId,
    required this.speakers,
    required this.microphones,
    this.sweepFStart = 20.0,
    this.sweepFEnd = 20000.0,
  });

  final String jobId;
  final String lobbyId;
  final List<SpeakerInfo> speakers;
  final List<MicrophoneInfo> microphones;

  /// Start frequency of the measurement sweep in Hz.
  final double sweepFStart;

  /// End frequency of the measurement sweep in Hz.
  final double sweepFEnd;

  @override
  List<Object?> get props => [
    jobId,
    lobbyId,
    speakers,
    microphones,
    sweepFStart,
    sweepFEnd,
  ];
}

/// Start measurement for the next speaker.
class MeasurementSessionStartSpeaker extends MeasurementSessionEvent {
  const MeasurementSessionStartSpeaker();
}

/// Local client signals ready.
class MeasurementSessionClientReady extends MeasurementSessionEvent {
  const MeasurementSessionClientReady();
}

/// Speaker signals playback finished.
class MeasurementSessionSpeakerFinished extends MeasurementSessionEvent {
  const MeasurementSessionSpeakerFinished();
}

/// Microphone signals recording uploaded.
class MeasurementSessionRecordingUploaded extends MeasurementSessionEvent {
  const MeasurementSessionRecordingUploaded({required this.uploadName});

  final String uploadName;

  @override
  List<Object?> get props => [uploadName];
}

/// Cancel the measurement session.
class MeasurementSessionCancelled extends MeasurementSessionEvent {
  const MeasurementSessionCancelled();
}

/// Join an existing measurement session (for non-admin devices like microphones).
class MeasurementSessionJoined extends MeasurementSessionEvent {
  const MeasurementSessionJoined({
    required this.sessionId,
    required this.jobId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String jobId;
  final String speakerSlotId;

  @override
  List<Object?> get props => [sessionId, jobId, speakerSlotId];
}

/// Reset to initial state.
class MeasurementSessionReset extends MeasurementSessionEvent {
  const MeasurementSessionReset();
}

// ============================================================
// New protocol internal events (11-step algorithm)
// ============================================================

/// Step 2: Server notifies all clients that measurement will start.
class _MeasurementStartNotification extends MeasurementSessionEvent {
  const _MeasurementStartNotification({
    required this.sessionId,
    required this.jobId,
  });

  final String sessionId;
  final String jobId;

  @override
  List<Object?> get props => [sessionId, jobId];
}

/// Step 4: Server tells speaker to request/download audio file.
class _MeasurementRequestAudio extends MeasurementSessionEvent {
  const _MeasurementRequestAudio({
    required this.sessionId,
    required this.audioEndpoint,
    this.expectedHash,
  });

  final String sessionId;
  final String audioEndpoint;
  final String? expectedHash;

  @override
  List<Object?> get props => [sessionId, audioEndpoint, expectedHash];
}

/// Step 6: Speaker signals audio is downloaded and verified.
class _MeasurementAudioReady extends MeasurementSessionEvent {
  const _MeasurementAudioReady({required this.sessionId});

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

/// Step 7: Server commands microphones to start recording.
class _MeasurementStartRecordingCommand extends MeasurementSessionEvent {
  const _MeasurementStartRecordingCommand({
    required this.sessionId,
    required this.jobId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String jobId;
  final String speakerSlotId;

  @override
  List<Object?> get props => [sessionId, jobId, speakerSlotId];
}

/// Step 8: Microphone confirms recording has started.
class _MeasurementRecordingStarted extends MeasurementSessionEvent {
  const _MeasurementRecordingStarted({required this.sessionId});

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

/// Step 9: Server commands speaker to start playback.
class _MeasurementStartPlaybackCommand extends MeasurementSessionEvent {
  const _MeasurementStartPlaybackCommand({
    required this.sessionId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String speakerSlotId;

  @override
  List<Object?> get props => [sessionId, speakerSlotId];
}

/// Step 10: Server commands microphones to stop recording and upload.
class _MeasurementStopRecordingCommand extends MeasurementSessionEvent {
  const _MeasurementStopRecordingCommand({
    required this.sessionId,
    required this.jobId,
    required this.speakerSlotId,
    required this.uploadEndpoint,
  });

  final String sessionId;
  final String jobId;
  final String speakerSlotId;
  final String uploadEndpoint;

  @override
  List<Object?> get props => [sessionId, jobId, speakerSlotId, uploadEndpoint];
}

// ============================================================
// Legacy internal events (for backward compatibility)
// ============================================================

/// Server requests microphone to prepare for recording.
class _MeasurementPrepareRecording extends MeasurementSessionEvent {
  const _MeasurementPrepareRecording({
    required this.sessionId,
    required this.jobId,
    required this.speakerSlotId,
    required this.expectedDuration,
  });

  final String sessionId;
  final String jobId;
  final String speakerSlotId;
  final double expectedDuration;

  @override
  List<Object?> get props => [
    sessionId,
    jobId,
    speakerSlotId,
    expectedDuration,
  ];
}

/// Server requests speaker to prepare for playback.
class _MeasurementPreparePlayback extends MeasurementSessionEvent {
  const _MeasurementPreparePlayback({
    required this.sessionId,
    required this.jobId,
    required this.audioFileEndpoint,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String jobId;
  final String audioFileEndpoint;
  final String speakerSlotId;

  @override
  List<Object?> get props => [
    sessionId,
    jobId,
    audioFileEndpoint,
    speakerSlotId,
  ];
}

/// Server signals speaker to start playback.
class _MeasurementStartPlayback extends MeasurementSessionEvent {
  const _MeasurementStartPlayback({
    required this.sessionId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String speakerSlotId;

  @override
  List<Object?> get props => [sessionId, speakerSlotId];
}

/// Internal event for microphones to start recording.
class _MeasurementStartRecording extends MeasurementSessionEvent {
  const _MeasurementStartRecording({
    required this.sessionId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String speakerSlotId;

  @override
  List<Object?> get props => [sessionId, speakerSlotId];
}

/// Server signals microphone to stop recording and upload.
class _MeasurementStopRecording extends MeasurementSessionEvent {
  const _MeasurementStopRecording({
    required this.sessionId,
    required this.jobId,
    required this.speakerSlotId,
    required this.uploadEndpoint,
  });

  final String sessionId;
  final String jobId;
  final String speakerSlotId;
  final String uploadEndpoint;

  @override
  List<Object?> get props => [sessionId, jobId, speakerSlotId, uploadEndpoint];
}

/// Server signals session is complete.
class _MeasurementSessionComplete extends MeasurementSessionEvent {
  const _MeasurementSessionComplete({
    required this.sessionId,
    required this.completedSpeakers,
  });

  final String sessionId;
  final List<String> completedSpeakers;

  @override
  List<Object?> get props => [sessionId, completedSpeakers];
}
