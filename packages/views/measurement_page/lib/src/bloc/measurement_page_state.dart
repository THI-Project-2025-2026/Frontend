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

/// A single displayable metric from the backend.
///
/// This is a universal format that allows the backend to define what metrics
/// to display without the frontend needing to know about specific metric types.
class DisplayMetric {
  const DisplayMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.formattedValue,
    this.unit,
    this.description,
    this.icon,
    this.category,
    this.sortOrder = 0,
  });

  factory DisplayMetric.fromJson(Map<String, dynamic> json) {
    return DisplayMetric(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      formattedValue: json['formatted_value'] as String? ?? '',
      unit: json['unit'] as String?,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Unique identifier for this metric (e.g., 'rt60', 'sti', 'c50')
  final String key;

  /// Human-readable label (e.g., 'RT60', 'Speech Transmission Index')
  final String label;

  /// Raw numeric value for calculations/comparisons
  final double value;

  /// Pre-formatted value string from backend (e.g., '1.23', '0.85')
  final String formattedValue;

  /// Unit to display after value (e.g., 's', 'dB', '%')
  final String? unit;

  /// Optional description/tooltip text
  final String? description;

  /// Optional icon identifier (mapped to Icons on frontend)
  final String? icon;

  /// Optional category for grouping (e.g., 'reverberation', 'clarity', 'quality')
  final String? category;

  /// Order for display sorting
  final int sortOrder;
}

/// Analysis results from the backend measurement processing.
///
/// Uses a universal format where the backend defines what metrics to display.
/// The frontend does not need to know about specific metric types.
class AnalysisResults {
  const AnalysisResults({required this.samplerateHz, required this.metrics});

  factory AnalysisResults.fromJson(Map<String, dynamic> json) {
    final metricsJson = json['display_metrics'] as List<dynamic>? ?? [];
    final metrics = metricsJson
        .map((m) => DisplayMetric.fromJson(m as Map<String, dynamic>))
        .toList();

    // Sort metrics by sortOrder
    metrics.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AnalysisResults(
      samplerateHz: (json['samplerate_hz'] as num?)?.toInt() ?? 48000,
      metrics: metrics,
    );
  }

  final int samplerateHz;

  /// Universal list of metrics to display - backend defines what's shown
  final List<DisplayMetric> metrics;
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
    this.measurementProfile = MeasurementProfile.highEnd,
    this.sweepStatus = SweepStatus.idle,
    this.jobId,
    this.audioHash,
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

  /// The selected measurement profile (affects sweep frequency range).
  final MeasurementProfile measurementProfile;
  final SweepStatus sweepStatus;
  final String? jobId;
  final String? audioHash;
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
    MeasurementProfile? measurementProfile,
    SweepStatus? sweepStatus,
    String? jobId,
    String? audioHash,
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
      measurementProfile: measurementProfile ?? this.measurementProfile,
      sweepStatus: sweepStatus ?? this.sweepStatus,
      jobId: jobId ?? this.jobId,
      audioHash: audioHash ?? this.audioHash,
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
