import 'package:equatable/equatable.dart';

/// The phase of a measurement cycle for a single speaker.
/// These phases follow the new 11-step protocol:
/// 1. initiating - Lobby creator tells backend to start
/// 2. notifyingClients - Server tells all clients measurement will start
/// 3. waitingReady - Waiting for all clients to send ready signal
/// 4. requestingAudio - Speaker requests audio file + hash
/// 5. downloadingAudio - Speaker downloading and verifying audio
/// 6. speakerConfirmed - Speaker tells backend it has working audiofile
/// 7. startingRecording - Backend tells microphones to start recording
/// 8. recording - Microphones recording, confirmed to backend
/// 9. playing - Backend told speaker to play, speaker is playing
/// 10. playbackComplete - Speaker finished, backend tells mics to stop
/// 11. uploadingRecordings - Microphones sending recordings to backend
enum MeasurementPhase {
  /// No measurement in progress.
  idle,

  /// Step 1: Lobby creator initiated measurement start.
  initiating,

  /// Step 2: Server notifying all clients that measurement will start.
  notifyingClients,

  /// Step 3: Waiting for all clients to send ready signal.
  waitingReady,

  /// Step 4: Speaker requesting audio file and hash from server.
  requestingAudio,

  /// Step 5: Speaker downloading and verifying audio file integrity.
  downloadingAudio,

  /// Step 6: Speaker confirmed it received working audiofile to backend.
  speakerConfirmed,

  /// Step 7: Backend telling microphones to start recording.
  startingRecording,

  /// Step 8: Microphones are recording, confirmed to backend.
  recording,

  /// Step 9: Speaker is playing the measurement signal.
  playing,

  /// Step 10: Speaker finished playback, backend told mics to stop.
  playbackComplete,

  /// Step 11: Microphones uploading recordings to backend.
  uploadingRecordings,

  /// Recording is complete, waiting for uploads (legacy compatibility).
  recordingComplete,

  /// Processing recordings on the server.
  processing,

  /// Measurement cycle completed successfully.
  completed,

  /// Measurement failed.
  failed,
}

/// The role of the local device in the measurement.
enum LocalMeasurementRole {
  /// Not participating in the current measurement.
  none,

  /// Device is the speaker playing audio.
  speaker,

  /// Device is recording as a microphone.
  microphone,
}

/// Information about the measurement audio signal structure.
class MeasurementAudioInfo extends Equatable {
  const MeasurementAudioInfo({
    required this.sampleRate,
    required this.totalDuration,
    required this.sweepStart,
    required this.sweepEnd,
    required this.segments,
  });

  factory MeasurementAudioInfo.fromJson(Map<String, dynamic> json) {
    return MeasurementAudioInfo(
      sampleRate: (json['sample_rate'] as num).toInt(),
      totalDuration: (json['total_duration'] as num).toDouble(),
      sweepStart: (json['sweep_start'] as num).toDouble(),
      sweepEnd: (json['sweep_end'] as num).toDouble(),
      segments: (json['segments'] as List<dynamic>)
          .map((s) => AudioSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  final int sampleRate;
  final double totalDuration;
  final double sweepStart;
  final double sweepEnd;
  final List<AudioSegment> segments;

  @override
  List<Object?> get props => [
    sampleRate,
    totalDuration,
    sweepStart,
    sweepEnd,
    segments,
  ];
}

/// A segment within the measurement audio.
class AudioSegment extends Equatable {
  const AudioSegment({
    required this.name,
    required this.type,
    required this.start,
    required this.end,
    this.fStart,
    this.fEnd,
  });

  factory AudioSegment.fromJson(Map<String, dynamic> json) {
    return AudioSegment(
      name: json['name'] as String,
      type: json['type'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      fStart: json['f_start'] != null
          ? (json['f_start'] as num).toDouble()
          : null,
      fEnd: json['f_end'] != null ? (json['f_end'] as num).toDouble() : null,
    );
  }

  final String name;
  final String type;
  final double start;
  final double end;
  final double? fStart;
  final double? fEnd;

  double get duration => end - start;

  @override
  List<Object?> get props => [name, type, start, end, fStart, fEnd];
}

/// Information about a speaker being measured.
class SpeakerInfo extends Equatable {
  const SpeakerInfo({
    required this.deviceId,
    required this.slotId,
    this.slotLabel,
    this.isCompleted = false,
  });

  final String deviceId;
  final String slotId;
  final String? slotLabel;
  final bool isCompleted;

  SpeakerInfo copyWith({
    String? deviceId,
    String? slotId,
    String? slotLabel,
    bool? isCompleted,
  }) {
    return SpeakerInfo(
      deviceId: deviceId ?? this.deviceId,
      slotId: slotId ?? this.slotId,
      slotLabel: slotLabel ?? this.slotLabel,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [deviceId, slotId, slotLabel, isCompleted];
}

/// Information about a microphone participating in measurement.
class MicrophoneInfo extends Equatable {
  const MicrophoneInfo({
    required this.deviceId,
    required this.slotId,
    this.slotLabel,
    this.isReady = false,
    this.hasUploaded = false,
  });

  final String deviceId;
  final String slotId;
  final String? slotLabel;
  final bool isReady;
  final bool hasUploaded;

  MicrophoneInfo copyWith({
    String? deviceId,
    String? slotId,
    String? slotLabel,
    bool? isReady,
    bool? hasUploaded,
  }) {
    return MicrophoneInfo(
      deviceId: deviceId ?? this.deviceId,
      slotId: slotId ?? this.slotId,
      slotLabel: slotLabel ?? this.slotLabel,
      isReady: isReady ?? this.isReady,
      hasUploaded: hasUploaded ?? this.hasUploaded,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    slotId,
    slotLabel,
    isReady,
    hasUploaded,
  ];
}

/// Full session information.
class MeasurementSessionInfo extends Equatable {
  const MeasurementSessionInfo({
    required this.sessionId,
    required this.jobId,
    required this.lobbyId,
    required this.speakers,
    required this.microphones,
    this.currentSpeakerIndex = 0,
    this.audioDurationSeconds = 15.0,
    this.sweepFStart = 20.0,
    this.sweepFEnd = 20000.0,
  });

  final String sessionId;
  final String jobId;
  final String lobbyId;
  final List<SpeakerInfo> speakers;
  final List<MicrophoneInfo> microphones;
  final int currentSpeakerIndex;
  final double audioDurationSeconds;

  /// Start frequency of the measurement sweep in Hz.
  final double sweepFStart;

  /// End frequency of the measurement sweep in Hz.
  final double sweepFEnd;

  SpeakerInfo? get currentSpeaker {
    if (currentSpeakerIndex < speakers.length) {
      return speakers[currentSpeakerIndex];
    }
    return null;
  }

  int get completedSpeakers => speakers.where((s) => s.isCompleted).length;
  int get totalSpeakers => speakers.length;
  bool get isComplete => completedSpeakers >= totalSpeakers;

  MeasurementSessionInfo copyWith({
    String? sessionId,
    String? jobId,
    String? lobbyId,
    List<SpeakerInfo>? speakers,
    List<MicrophoneInfo>? microphones,
    int? currentSpeakerIndex,
    double? audioDurationSeconds,
    double? sweepFStart,
    double? sweepFEnd,
  }) {
    return MeasurementSessionInfo(
      sessionId: sessionId ?? this.sessionId,
      jobId: jobId ?? this.jobId,
      lobbyId: lobbyId ?? this.lobbyId,
      speakers: speakers ?? this.speakers,
      microphones: microphones ?? this.microphones,
      currentSpeakerIndex: currentSpeakerIndex ?? this.currentSpeakerIndex,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      sweepFStart: sweepFStart ?? this.sweepFStart,
      sweepFEnd: sweepFEnd ?? this.sweepFEnd,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    jobId,
    lobbyId,
    speakers,
    microphones,
    currentSpeakerIndex,
    audioDurationSeconds,
    sweepFStart,
    sweepFEnd,
  ];
}
