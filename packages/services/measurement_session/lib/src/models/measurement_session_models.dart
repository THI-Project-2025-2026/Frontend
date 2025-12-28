import 'package:equatable/equatable.dart';

/// The phase of a measurement cycle for a single speaker.
enum MeasurementPhase {
  /// No measurement in progress.
  idle,

  /// Preparing for measurement (downloading audio, etc.).
  preparing,

  /// Waiting for all clients to signal ready.
  waitingReady,

  /// Speaker is playing the measurement signal.
  playing,

  /// Recording is complete, waiting for uploads.
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
  });

  final String sessionId;
  final String jobId;
  final String lobbyId;
  final List<SpeakerInfo> speakers;
  final List<MicrophoneInfo> microphones;
  final int currentSpeakerIndex;
  final double audioDurationSeconds;

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
  }) {
    return MeasurementSessionInfo(
      sessionId: sessionId ?? this.sessionId,
      jobId: jobId ?? this.jobId,
      lobbyId: lobbyId ?? this.lobbyId,
      speakers: speakers ?? this.speakers,
      microphones: microphones ?? this.microphones,
      currentSpeakerIndex: currentSpeakerIndex ?? this.currentSpeakerIndex,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
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
  ];
}
