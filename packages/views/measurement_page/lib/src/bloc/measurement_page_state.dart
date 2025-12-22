part of 'measurement_page_bloc.dart';

/// Roles a device can take within a collaborative measurement session.
enum MeasurementDeviceRole { none, microphone, loudspeaker }

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
      MeasurementStepDescriptor(
        index: 5,
        titleKey: 'measurement_page.timeline.steps.4.title',
        descriptionKey: 'measurement_page.timeline.steps.4.description',
      ),
      MeasurementStepDescriptor(
        index: 6,
        titleKey: 'measurement_page.timeline.steps.5.title',
        descriptionKey: 'measurement_page.timeline.steps.5.description',
      ),
      MeasurementStepDescriptor(
        index: 7,
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
    );
  }
}
