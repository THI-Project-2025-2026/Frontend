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

/// Changes the measurement profile (frequency range).
class MeasurementProfileChanged extends MeasurementPageEvent {
  const MeasurementProfileChanged({required this.profile});

  final MeasurementProfile profile;
}

/// Internal event to mark a job as created.
class MeasurementJobCreated extends MeasurementPageEvent {
  const MeasurementJobCreated({required this.jobId});

  final String jobId;
}

/// Internal event when this device receives a measurement start notification.
/// This is used for non-admin devices to join an ongoing measurement.
class _MeasurementStartReceived extends MeasurementPageEvent {
  const _MeasurementStartReceived({
    required this.sessionId,
    required this.jobId,
    required this.speakerDeviceId,
    required this.speakerSlotId,
  });

  final String sessionId;
  final String jobId;
  final String speakerDeviceId;
  final String speakerSlotId;
}

/// Internal event when the session state changes.
/// Used to propagate session bloc state to this bloc via events instead of
/// direct emit calls in stream listeners.
class _SessionStateChanged extends MeasurementPageEvent {
  const _SessionStateChanged({required this.sessionState});

  final MeasurementSessionState sessionState;
}

/// Internal event to request analysis from the backend.
class _AnalysisRequested extends MeasurementPageEvent {
  const _AnalysisRequested();
}

/// Internal event when analysis results are received.
class _AnalysisResultsReceived extends MeasurementPageEvent {
  const _AnalysisResultsReceived({required this.results});

  final AnalysisResults results;
}

/// Internal event when analysis fails.
class _AnalysisFailed extends MeasurementPageEvent {
  const _AnalysisFailed({required this.error});

  final String error;
}

/// Internal event when phase update is received from the server.
/// This keeps all clients in sync with the current measurement timeline step.
class _PhaseUpdateReceived extends MeasurementPageEvent {
  const _PhaseUpdateReceived({
    required this.phase,
    required this.phaseDescription,
  });

  final String phase;
  final String phaseDescription;
}

/// Internal event when analysis results are broadcast from server.
/// This delivers results to ALL clients, not just the admin.
class _AnalysisResultsBroadcastReceived extends MeasurementPageEvent {
  const _AnalysisResultsBroadcastReceived({required this.results});

  final Map<String, dynamic> results;
}

/// Internal event when timeline step update is received from lobby host.
/// This keeps all clients synchronized on the measurement timeline step.
class _StepUpdateReceived extends MeasurementPageEvent {
  const _StepUpdateReceived({required this.stepIndex});

  final int stepIndex;
}

/// Internal event when measurement profile update is received from lobby host.
/// This keeps all clients synchronized on the measurement profile.
class _ProfileUpdateReceived extends MeasurementPageEvent {
  const _ProfileUpdateReceived({required this.profileId});

  final String profileId;
}

/// Internal event to broadcast current state to all participants.
/// Triggered when a new participant joins the lobby.
class _BroadcastCurrentState extends MeasurementPageEvent {
  const _BroadcastCurrentState();
}
