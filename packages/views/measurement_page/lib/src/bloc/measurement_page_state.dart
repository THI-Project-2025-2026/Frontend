part of 'measurement_page_bloc.dart';

/// Roles a device can take within a collaborative measurement session.
enum MeasurementDeviceRole { none, microphone, loudspeaker }

/// Status of the sweep measurement process.
enum SweepStatus {
  /// No sweep in progress.
  idle,

  /// Creating job on the server.
  creatingJob,

  /// Sweep session is being created.
  creatingSession,

  /// Sweep is in progress (synchronized playback and recording).
  running,

  /// Recordings uploaded, requesting analysis from backend.
  requestingAnalysis,

  /// Sweep completed successfully with analysis results.
  completed,

  /// Sweep failed or was cancelled.
  failed,
}

/// Analysis results from the backend measurement processing.
class AnalysisResults {
  const AnalysisResults({
    required this.samplerateHz,
    required this.rt,
    required this.clarity,
    required this.drr,
    required this.quality,
    required this.frequencyResponse,
    required this.sti,
  });

  factory AnalysisResults.fromJson(Map<String, dynamic> json) {
    // The 'sti' field from backend is a Map containing the actual STI value
    final stiData = json['sti'];
    double stiValue = 0.0;
    if (stiData is Map<String, dynamic>) {
      stiValue = (stiData['sti'] as num?)?.toDouble() ?? 0.0;
    } else if (stiData is num) {
      stiValue = stiData.toDouble();
    }

    return AnalysisResults(
      samplerateHz: (json['samplerate_hz'] as num?)?.toInt() ?? 48000,
      rt: RtMetrics.fromJson(json['rt'] as Map<String, dynamic>? ?? {}),
      clarity: ClarityMetrics.fromJson(
        json['clarity'] as Map<String, dynamic>? ?? {},
      ),
      drr: DrrMetrics.fromJson(json['drr'] as Map<String, dynamic>? ?? {}),
      quality: QualityMetrics.fromJson(
        json['quality'] as Map<String, dynamic>? ?? {},
      ),
      frequencyResponse: FrequencyResponseMetrics.fromJson(
        json['frequency_response'] as Map<String, dynamic>? ?? {},
      ),
      sti: stiValue,
    );
  }

  final int samplerateHz;
  final RtMetrics rt;
  final ClarityMetrics clarity;
  final DrrMetrics drr;
  final QualityMetrics quality;
  final FrequencyResponseMetrics frequencyResponse;
  final double sti;
}

/// Reverberation time metrics.
class RtMetrics {
  const RtMetrics({this.rt60 = 0.0, this.rt30 = 0.0, this.edt = 0.0});

  factory RtMetrics.fromJson(Map<String, dynamic> json) {
    return RtMetrics(
      // Backend uses _s suffix for seconds
      rt60: (json['rt60_s'] as num?)?.toDouble() ?? 0.0,
      rt30: (json['t30_rt60_s'] as num?)?.toDouble() ?? 0.0,
      edt: (json['edt_s'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double rt60;
  final double rt30;
  final double edt;
}

/// Clarity and definition metrics.
class ClarityMetrics {
  const ClarityMetrics({
    this.c50 = 0.0,
    this.c80 = 0.0,
    this.d50 = 0.0,
    this.d80 = 0.0,
  });

  factory ClarityMetrics.fromJson(Map<String, dynamic> json) {
    return ClarityMetrics(
      // Backend uses _db suffix for dB values
      c50: (json['c50_db'] as num?)?.toDouble() ?? 0.0,
      c80: (json['c80_db'] as num?)?.toDouble() ?? 0.0,
      d50: (json['d50'] as num?)?.toDouble() ?? 0.0,
      d80: (json['d80'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double c50;
  final double c80;
  final double d50;
  final double d80;
}

/// Direct-to-reverberant ratio metrics.
class DrrMetrics {
  const DrrMetrics({this.drr = 0.0});

  factory DrrMetrics.fromJson(Map<String, dynamic> json) {
    // Backend uses _db suffix for dB values
    return DrrMetrics(drr: (json['drr_db'] as num?)?.toDouble() ?? 0.0);
  }

  final double drr;
}

/// Signal quality metrics.
class QualityMetrics {
  const QualityMetrics({this.snr = 0.0, this.noiseFloor = 0.0});

  factory QualityMetrics.fromJson(Map<String, dynamic> json) {
    return QualityMetrics(
      // Backend uses _db suffix for dB values
      snr: (json['snr_db'] as num?)?.toDouble() ?? 0.0,
      noiseFloor: (json['noise_floor_db'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double snr;
  final double noiseFloor;
}

/// Frequency response metrics.
class FrequencyResponseMetrics {
  const FrequencyResponseMetrics({
    this.lowFreqEnergy = 0.0,
    this.midFreqEnergy = 0.0,
    this.highFreqEnergy = 0.0,
  });

  factory FrequencyResponseMetrics.fromJson(Map<String, dynamic> json) {
    return FrequencyResponseMetrics(
      lowFreqEnergy: (json['low_freq_energy'] as num?)?.toDouble() ?? 0.0,
      midFreqEnergy: (json['mid_freq_energy'] as num?)?.toDouble() ?? 0.0,
      highFreqEnergy: (json['high_freq_energy'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final double lowFreqEnergy;
  final double midFreqEnergy;
  final double highFreqEnergy;
}

/// Metadata for the measurement step timeline.
class MeasurementStepDescriptor {
  const MeasurementStepDescriptor({
    required this.index,
    required this.titleKey,
    required this.descriptionKey,
    this.fallbackTitle,
    this.fallbackDescription,
  });

  final int index;
  final String titleKey;
  final String descriptionKey;
  final String? fallbackTitle;
  final String? fallbackDescription;
}

/// Playback phases within the sweep dialog.
enum PlaybackPhase { idle, measurementPlaying }

/// Representation of a connected device in the lobby.
class MeasurementDevice {
  const MeasurementDevice({
    required this.id,
    required this.name,
    required this.role,
    required this.isLocal,
    required this.isReady,
    required this.latencyMs,
    required this.batteryLevel,
    this.roleSlotId,
    this.roleLabel,
    this.roleColor,
  });

  final String id;
  final String name;
  final MeasurementDeviceRole role;
  final bool isLocal;
  final bool isReady;
  final int latencyMs;
  final double batteryLevel;
  final String? roleSlotId;
  final String? roleLabel;
  final Color? roleColor;

  MeasurementDevice copyWith({
    String? id,
    String? name,
    MeasurementDeviceRole? role,
    bool? isLocal,
    bool? isReady,
    int? latencyMs,
    double? batteryLevel,
    String? roleSlotId,
    String? roleLabel,
    Color? roleColor,
  }) {
    return MeasurementDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isLocal: isLocal ?? this.isLocal,
      isReady: isReady ?? this.isReady,
      latencyMs: latencyMs ?? this.latencyMs,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      roleSlotId: roleSlotId ?? this.roleSlotId,
      roleLabel: roleLabel ?? this.roleLabel,
      roleColor: roleColor ?? this.roleColor,
    );
  }
}

@immutable
class MeasurementPageState {
  MeasurementPageState({
    required this.lobbyActive,
    required this.lobbyId,
    required this.lobbyCode,
    required this.inviteLink,
    required this.showQr,
    required List<MeasurementDevice> devices,
    required List<MeasurementStepDescriptor> steps,
    required this.activeStepIndex,
    required this.lastActionMessage,
    required this.lastUpdated,
    this.isHost = false,
    this.currentDeviceId = '',
    this.sharedRoomPlan,
    this.sharedRoomPlanVersion = 0,
    this.sweepStatus = SweepStatus.idle,
    this.jobId,
    this.sweepError,
    this.playbackPhase = PlaybackPhase.idle,
    this.analysisResults,
  }) : devices = List<MeasurementDevice>.unmodifiable(devices),
       steps = List<MeasurementStepDescriptor>.unmodifiable(steps);

  final bool lobbyActive;
  final String lobbyId;
  final String lobbyCode;
  final String inviteLink;
  final bool showQr;
  final List<MeasurementDevice> devices;
  final List<MeasurementStepDescriptor> steps;
  final int activeStepIndex;
  final String lastActionMessage;
  final DateTime lastUpdated;
  final bool isHost;
  final String currentDeviceId;
  final Map<String, dynamic>? sharedRoomPlan;
  final int sharedRoomPlanVersion;
  final SweepStatus sweepStatus;
  final String? jobId;
  final String? sweepError;
  final PlaybackPhase playbackPhase;
  final AnalysisResults? analysisResults;

  MeasurementDevice? get localDevice {
    for (final device in devices) {
      if (device.isLocal) {
        return device;
      }
    }
    if (devices.isEmpty) {
      return null;
    }
    return devices.first;
  }

  /// Get all devices with the speaker role.
  List<MeasurementDevice> get speakers => devices
      .where((d) => d.role == MeasurementDeviceRole.loudspeaker)
      .toList();

  /// Get all devices with the microphone role.
  List<MeasurementDevice> get microphones =>
      devices.where((d) => d.role == MeasurementDeviceRole.microphone).toList();

  /// Check if there are enough devices to start measurement.
  bool get canStartMeasurement =>
      speakers.isNotEmpty && microphones.isNotEmpty && lobbyActive;

  MeasurementStepDescriptor? get activeStep {
    if (steps.isEmpty) {
      return null;
    }
    final index = activeStepIndex.clamp(0, steps.length - 1);
    return steps[index];
  }

  MeasurementPageState copyWith({
    bool? lobbyActive,
    String? lobbyId,
    String? lobbyCode,
    String? inviteLink,
    bool? showQr,
    List<MeasurementDevice>? devices,
    List<MeasurementStepDescriptor>? steps,
    int? activeStepIndex,
    String? lastActionMessage,
    DateTime? lastUpdated,
    bool? isHost,
    String? currentDeviceId,
    Map<String, dynamic>? sharedRoomPlan,
    int? sharedRoomPlanVersion,
    SweepStatus? sweepStatus,
    String? jobId,
    String? sweepError,
    PlaybackPhase? playbackPhase,
    AnalysisResults? analysisResults,
  }) {
    return MeasurementPageState(
      lobbyActive: lobbyActive ?? this.lobbyActive,
      lobbyId: lobbyId ?? this.lobbyId,
      lobbyCode: lobbyCode ?? this.lobbyCode,
      inviteLink: inviteLink ?? this.inviteLink,
      showQr: showQr ?? this.showQr,
      devices: devices ?? this.devices,
      steps: steps ?? this.steps,
      activeStepIndex: activeStepIndex ?? this.activeStepIndex,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isHost: isHost ?? this.isHost,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      sharedRoomPlan: sharedRoomPlan ?? this.sharedRoomPlan,
      sharedRoomPlanVersion:
          sharedRoomPlanVersion ?? this.sharedRoomPlanVersion,
      sweepStatus: sweepStatus ?? this.sweepStatus,
      jobId: jobId ?? this.jobId,
      sweepError: sweepError ?? this.sweepError,
      playbackPhase: playbackPhase ?? this.playbackPhase,
      analysisResults: analysisResults ?? this.analysisResults,
    );
  }

  static MeasurementPageState initial() {
    const steps = <MeasurementStepDescriptor>[
      MeasurementStepDescriptor(
        index: 0,
        titleKey: 'measurement_page.timeline.steps.0.title',
        descriptionKey: 'measurement_page.timeline.steps.0.description',
      ),
      MeasurementStepDescriptor(
        index: 1,
        titleKey: 'measurement_page.timeline.steps.1.title',
        descriptionKey: 'measurement_page.timeline.steps.1.description',
      ),
      MeasurementStepDescriptor(
        index: 2,
        titleKey: 'measurement_page.timeline.steps.2.title',
        descriptionKey: 'measurement_page.timeline.steps.2.description',
      ),
      MeasurementStepDescriptor(
        index: 3,
        titleKey: 'measurement_page.timeline.steps.devices.title',
        descriptionKey: 'measurement_page.timeline.steps.devices.description',
        fallbackTitle: 'Place speakers and microphones',
        fallbackDescription:
            'Add at least one speaker and one microphone inside the room.',
      ),
      MeasurementStepDescriptor(
        index: 4,
        titleKey: 'measurement_page.timeline.steps.3.title',
        descriptionKey: 'measurement_page.timeline.steps.3.description',
      ),
      // Note: Step 4 (synchronize devices) removed - synchronization happens
      // automatically at the beginning of the sweep step.
      MeasurementStepDescriptor(
        index: 5,
        titleKey: 'measurement_page.timeline.steps.5.title',
        descriptionKey: 'measurement_page.timeline.steps.5.description',
      ),
      MeasurementStepDescriptor(
        index: 6,
        titleKey: 'measurement_page.timeline.steps.6.title',
        descriptionKey: 'measurement_page.timeline.steps.6.description',
      ),
    ];

    const devices = <MeasurementDevice>[
      MeasurementDevice(
        id: 'local-device',
        name: 'measurement_page.devices.local_name',
        role: MeasurementDeviceRole.none,
        isLocal: true,
        isReady: false,
        latencyMs: 0,
        batteryLevel: 1.0,
        roleSlotId: null,
        roleLabel: null,
        roleColor: null,
      ),
    ];

    return MeasurementPageState(
      lobbyActive: false,
      lobbyId: '',
      lobbyCode: '',
      inviteLink: '',
      showQr: false,
      devices: devices,
      steps: steps,
      activeStepIndex: 0,
      lastActionMessage: 'measurement_page.lobby.status_idle',
      lastUpdated: DateTime.now(),
      sharedRoomPlan: null,
      sharedRoomPlanVersion: 0,
      playbackPhase: PlaybackPhase.idle,
    );
  }
}
