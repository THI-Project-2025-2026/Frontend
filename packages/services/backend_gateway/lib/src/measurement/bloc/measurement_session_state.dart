part of 'measurement_session_bloc.dart';

/// Status of the measurement session.
enum MeasurementSessionStatus {
  /// Initial state, no session active.
  initial,

  /// Creating a new session.
  creating,

  /// Session created, ready to start.
  created,

  /// Preparing for measurement (downloading audio, setting up recording).
  preparingMeasurement,

  /// Measurement in progress.
  measuring,

  /// Processing recordings.
  processing,

  /// Session completed successfully.
  completed,

  /// Session was cancelled.
  cancelled,

  /// An error occurred.
  error,
}

/// State of the measurement session.
class MeasurementSessionState extends Equatable {
  const MeasurementSessionState({
    this.status = MeasurementSessionStatus.initial,
    this.phase = MeasurementPhase.idle,
    this.phaseDescription = '',
    this.sessionInfo,
    this.localRole = LocalMeasurementRole.none,
    this.isLocalReady = false,
    this.audioInfo,
    this.audioHash,
    this.error,
    this.playbackProgress = 0.0,
    this.recordingDuration = Duration.zero,
    this.analysisResults,
  });

  /// Overall session status.
  final MeasurementSessionStatus status;

  /// Current measurement phase (for active speaker).
  final MeasurementPhase phase;

  /// Human-readable description of the current phase.
  final String phaseDescription;

  /// Session information.
  final MeasurementSessionInfo? sessionInfo;

  /// Role of the local device in the current measurement.
  final LocalMeasurementRole localRole;

  /// Whether the local device is ready.
  final bool isLocalReady;

  /// Information about the measurement audio.
  final MeasurementAudioInfo? audioInfo;

  /// Hash of the downloaded measurement audio (for analysis).
  final String? audioHash;

  /// Error message if any.
  final String? error;

  /// Playback progress (0.0 to 1.0) for speakers.
  final double playbackProgress;

  /// Recording duration for microphones.
  final Duration recordingDuration;

  /// Analysis results from the backend (broadcast to all clients).
  final Map<String, dynamic>? analysisResults;

  /// Whether a session is active.
  bool get hasActiveSession =>
      sessionInfo != null &&
      status != MeasurementSessionStatus.initial &&
      status != MeasurementSessionStatus.completed &&
      status != MeasurementSessionStatus.cancelled &&
      status != MeasurementSessionStatus.error;

  /// Whether the local device is the current speaker.
  bool get isLocalSpeaker => localRole == LocalMeasurementRole.speaker;

  /// Whether the local device is a microphone.
  bool get isLocalMicrophone => localRole == LocalMeasurementRole.microphone;

  /// Progress as a string for display.
  String get progressText {
    final session = sessionInfo;
    if (session == null) return '';
    return '${session.completedSpeakers + 1}/${session.totalSpeakers}';
  }

  MeasurementSessionState copyWith({
    MeasurementSessionStatus? status,
    MeasurementPhase? phase,
    String? phaseDescription,
    MeasurementSessionInfo? sessionInfo,
    LocalMeasurementRole? localRole,
    bool? isLocalReady,
    MeasurementAudioInfo? audioInfo,
    String? audioHash,
    String? error,
    double? playbackProgress,
    Duration? recordingDuration,
    Map<String, dynamic>? analysisResults,
  }) {
    return MeasurementSessionState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      phaseDescription: phaseDescription ?? this.phaseDescription,
      sessionInfo: sessionInfo ?? this.sessionInfo,
      localRole: localRole ?? this.localRole,
      isLocalReady: isLocalReady ?? this.isLocalReady,
      audioInfo: audioInfo ?? this.audioInfo,
      audioHash: audioHash ?? this.audioHash,
      error: error ?? this.error,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      analysisResults: analysisResults ?? this.analysisResults,
    );
  }

  @override
  List<Object?> get props => [
    status,
    phase,
    phaseDescription,
    sessionInfo,
    localRole,
    isLocalReady,
    audioInfo,
    audioHash,
    error,
    playbackProgress,
    recordingDuration,
    analysisResults,
  ];
}
