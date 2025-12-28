/// Coordinated acoustic measurement session service.
///
/// This library provides the client-side implementation of the synchronized
/// acoustic measurement protocol, including:
/// - Session state management
/// - Audio playback (speaker role)
/// - Audio recording (microphone role)
/// - Backend event coordination
library;

export 'src/bloc/measurement_session_bloc.dart';
export 'src/models/measurement_session_models.dart';
export 'src/services/audio_playback_service.dart';
export 'src/services/measurement_audio_service.dart';
