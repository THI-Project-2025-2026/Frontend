part of 'measurement_page_bloc.dart';

/// Roles a device can take within a collaborative measurement session.
enum MeasurementDeviceRole { receiver, sender, coordinator }

/// Metadata for the measurement step timeline.
class MeasurementStepDescriptor {
  const MeasurementStepDescriptor({
    required this.index,
    required this.titleKey,
    required this.descriptionKey,
  });

  final int index;
  final String titleKey;
  final String descriptionKey;
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
  });

  final String id;
  final String name;
  final MeasurementDeviceRole role;
  final bool isLocal;
  final bool isReady;
  final int latencyMs;
  final double batteryLevel;

  MeasurementDevice copyWith({
    String? id,
    String? name,
    MeasurementDeviceRole? role,
    bool? isLocal,
    bool? isReady,
    int? latencyMs,
    double? batteryLevel,
  }) {
    return MeasurementDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isLocal: isLocal ?? this.isLocal,
      isReady: isReady ?? this.isReady,
      latencyMs: latencyMs ?? this.latencyMs,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }
}

@immutable
class MeasurementPageState {
  MeasurementPageState({
    required this.lobbyActive,
    required this.lobbyCode,
    required this.inviteLink,
    required this.showQr,
    required this.selectedRole,
    required List<MeasurementDevice> devices,
    required List<MeasurementStepDescriptor> steps,
    required this.activeStepIndex,
    required this.uplinkRssi,
    required this.downlinkRssi,
    required this.networkJitterMs,
    required this.isScanning,
    required this.lastActionMessage,
    required this.lastUpdated,
  }) : devices = List<MeasurementDevice>.unmodifiable(devices),
       steps = List<MeasurementStepDescriptor>.unmodifiable(steps);

  final bool lobbyActive;
  final String lobbyCode;
  final String inviteLink;
  final bool showQr;
  final MeasurementDeviceRole selectedRole;
  final List<MeasurementDevice> devices;
  final List<MeasurementStepDescriptor> steps;
  final int activeStepIndex;
  final double uplinkRssi;
  final double downlinkRssi;
  final double networkJitterMs;
  final bool isScanning;
  final String lastActionMessage;
  final DateTime lastUpdated;

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
    String? lobbyCode,
    String? inviteLink,
    bool? showQr,
    MeasurementDeviceRole? selectedRole,
    List<MeasurementDevice>? devices,
    List<MeasurementStepDescriptor>? steps,
    int? activeStepIndex,
    double? uplinkRssi,
    double? downlinkRssi,
    double? networkJitterMs,
    bool? isScanning,
    String? lastActionMessage,
    DateTime? lastUpdated,
  }) {
    return MeasurementPageState(
      lobbyActive: lobbyActive ?? this.lobbyActive,
      lobbyCode: lobbyCode ?? this.lobbyCode,
      inviteLink: inviteLink ?? this.inviteLink,
      showQr: showQr ?? this.showQr,
      selectedRole: selectedRole ?? this.selectedRole,
      devices: devices ?? this.devices,
      steps: steps ?? this.steps,
      activeStepIndex: activeStepIndex ?? this.activeStepIndex,
      uplinkRssi: uplinkRssi ?? this.uplinkRssi,
      downlinkRssi: downlinkRssi ?? this.downlinkRssi,
      networkJitterMs: networkJitterMs ?? this.networkJitterMs,
      isScanning: isScanning ?? this.isScanning,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
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
        titleKey: 'measurement_page.timeline.steps.3.title',
        descriptionKey: 'measurement_page.timeline.steps.3.description',
      ),
    ];

    const devices = <MeasurementDevice>[
      MeasurementDevice(
        id: 'local-device',
        name: 'Host device',
        role: MeasurementDeviceRole.receiver,
        isLocal: true,
        isReady: false,
        latencyMs: 12,
        batteryLevel: 0.92,
      ),
    ];

    return MeasurementPageState(
      lobbyActive: false,
      lobbyCode: '',
      inviteLink: '',
      showQr: false,
      selectedRole: MeasurementDeviceRole.receiver,
      devices: devices,
      steps: steps,
      activeStepIndex: 0,
      uplinkRssi: -52,
      downlinkRssi: -54,
      networkJitterMs: 6,
      isScanning: false,
      lastActionMessage: 'measurement_page.lobby.status_idle',
      lastUpdated: DateTime.now(),
    );
  }
}
