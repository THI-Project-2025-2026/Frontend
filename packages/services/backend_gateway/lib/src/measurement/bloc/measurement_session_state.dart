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
    this.sessionInfo,
    this.localRole = LocalMeasurementRole.none,
    this.isLocalReady = false,
    this.audioInfo,
    this.error,
    this.playbackProgress = 0.0,
    this.recordingDuration = Duration.zero,
  });

  /// Overall session status.
  final MeasurementSessionStatus status;

  /// Current measurement phase (for active speaker).
  final MeasurementPhase phase;

  /// Session information.
  final MeasurementSessionInfo? sessionInfo;

  /// Role of the local device in the current measurement.
  final LocalMeasurementRole localRole;

  /// Whether the local device is ready.
  final bool isLocalReady;

  /// Information about the measurement audio.
  final MeasurementAudioInfo? audioInfo;

  /// Error message if any.
  final String? error;

  /// Playback progress (0.0 to 1.0) for speakers.
  final double playbackProgress;

  /// Recording duration for microphones.
  final Duration recordingDuration;

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
    MeasurementSessionInfo? sessionInfo,
    LocalMeasurementRole? localRole,
    bool? isLocalReady,
    MeasurementAudioInfo? audioInfo,
    String? error,
    double? playbackProgress,
    Duration? recordingDuration,
  }) {
    return MeasurementSessionState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      sessionInfo: sessionInfo ?? this.sessionInfo,
      localRole: localRole ?? this.localRole,
      isLocalReady: isLocalReady ?? this.isLocalReady,
      audioInfo: audioInfo ?? this.audioInfo,
      error: error ?? this.error,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      recordingDuration: recordingDuration ?? this.recordingDuration,
    );
  }

  @override
  List<Object?> get props => [
    status,
    phase,
    sessionInfo,
    localRole,
    isLocalReady,
    audioInfo,
    error,
    playbackProgress,
    recordingDuration,
  ];
}
