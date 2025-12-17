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

/// Changes the role for a specific device.
class MeasurementDeviceRoleChanged extends MeasurementPageEvent {
  const MeasurementDeviceRoleChanged({
    required this.deviceId,
    required this.role,
  });

  final String deviceId;
  final MeasurementDeviceRole role;
}

/// Toggles ready state for a specific device in the lobby.
class MeasurementDeviceReadyToggled extends MeasurementPageEvent {
  const MeasurementDeviceReadyToggled(this.deviceId);

  final String deviceId;
}

/// Joins an existing lobby with the given code.
class MeasurementLobbyJoined extends MeasurementPageEvent {
  const MeasurementLobbyJoined({required this.code});

  final String code;
}

/// Refreshes the lobby state from the backend.
class MeasurementLobbyRefreshed extends MeasurementPageEvent {
  const MeasurementLobbyRefreshed();
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

/// Advances the measurement timeline to the next step.
class MeasurementTimelineAdvanced extends MeasurementPageEvent {
  const MeasurementTimelineAdvanced();
}

/// Steps the measurement timeline back to the previous step.
class MeasurementTimelineStepBack extends MeasurementPageEvent {
  const MeasurementTimelineStepBack();
}
