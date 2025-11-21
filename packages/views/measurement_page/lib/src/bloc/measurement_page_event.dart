part of 'measurement_page_bloc.dart';

@immutable
sealed class MeasurementPageEvent {
  const MeasurementPageEvent();
}

/// Creates a new lobby or restarts the existing one.
class MeasurementLobbyCreated extends MeasurementPageEvent {
  const MeasurementLobbyCreated();
}

/// Toggles the QR code preview visibility.
class MeasurementLobbyQrToggled extends MeasurementPageEvent {
  const MeasurementLobbyQrToggled();
}

/// Refreshes the lobby code and invite link.
class MeasurementLobbyCodeRefreshed extends MeasurementPageEvent {
  const MeasurementLobbyCodeRefreshed();
}

/// Marks the invite link as copied (used for feedback messaging).
class MeasurementLobbyLinkCopied extends MeasurementPageEvent {
  const MeasurementLobbyLinkCopied();
}

/// Selects the active role for the local device.
class MeasurementRoleSelected extends MeasurementPageEvent {
  const MeasurementRoleSelected(this.role);

  final MeasurementDeviceRole role;
}

/// Toggles ready state for a specific device in the lobby.
class MeasurementDeviceReadyToggled extends MeasurementPageEvent {
  const MeasurementDeviceReadyToggled(this.deviceId);

  final String deviceId;
}

/// Adds a demo remote device into the lobby.
class MeasurementDeviceDemoJoined extends MeasurementPageEvent {
  const MeasurementDeviceDemoJoined({required this.alias});

  final String alias;
}

/// Removes a device from the lobby (demo control).
class MeasurementDeviceDemoLeft extends MeasurementPageEvent {
  const MeasurementDeviceDemoLeft({required this.deviceId});

  final String deviceId;
}

/// Periodic tick to refresh synthetic telemetry.
class MeasurementTelemetryTick extends MeasurementPageEvent {
  const MeasurementTelemetryTick();
}

/// Advances the measurement timeline to the next step.
class MeasurementTimelineAdvanced extends MeasurementPageEvent {
  const MeasurementTimelineAdvanced();
}

/// Toggles device discovery scanning indicator.
class MeasurementScanningToggled extends MeasurementPageEvent {
  const MeasurementScanningToggled();
}
