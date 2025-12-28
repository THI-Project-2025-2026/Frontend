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
    this.roleSlotId,
    this.roleLabel,
    this.roleColor,
  });

  final String deviceId;
  final MeasurementDeviceRole role;
  final String? roleSlotId;
  final String? roleLabel;
  final Color? roleColor;
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

/// Advances the measurement timeline to the next step.
class MeasurementTimelineAdvanced extends MeasurementPageEvent {
  const MeasurementTimelineAdvanced();
}

/// Steps the measurement timeline back to the previous step.
class MeasurementTimelineStepBack extends MeasurementPageEvent {
  const MeasurementTimelineStepBack();
}

class MeasurementRoomPlanReceived extends MeasurementPageEvent {
  const MeasurementRoomPlanReceived({required this.roomJson});

  final Map<String, dynamic> roomJson;
}

/// Request to start the measurement sweep.
///
/// This will create a measurement job and session, then start coordinating
/// between speakers and microphones. Synchronization happens automatically
/// at the beginning of each sweep.
class MeasurementSweepStartRequested extends MeasurementPageEvent {
  const MeasurementSweepStartRequested();
}

/// Cancels the ongoing measurement sweep.
class MeasurementSweepCancelled extends MeasurementPageEvent {
  const MeasurementSweepCancelled();
}

/// Internal event to mark a job as created.
class MeasurementJobCreated extends MeasurementPageEvent {
  const MeasurementJobCreated({required this.jobId});

  final String jobId;
}
