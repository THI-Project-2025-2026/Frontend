part of 'json_hot_reload_bloc.dart';

/// Base class for JSON hot reload states.
///
/// This sealed class defines all possible states of the JsonHotReloadBloc.
@immutable
sealed class JsonHotReloadState {
  const JsonHotReloadState();
}

/// Initial state when the file watching system is not started.
class JsonHotReloadInitial extends JsonHotReloadState {
  const JsonHotReloadInitial();
}

/// State indicating that file watching is active.
class JsonFileWatchingActive extends JsonHotReloadState {
  const JsonFileWatchingActive();
}

/// State indicating that file watching has been stopped.
class JsonFileWatchingStopped extends JsonHotReloadState {
  const JsonFileWatchingStopped();
}

/// State indicating that a translation file has been reloaded.
///
/// @param languageCode:
///   - type: String
///   - description: The language code that was reloaded.
/// @param timestamp:
///   - type: DateTime
///   - description: The timestamp when the reload occurred.
class TranslationReloaded extends JsonHotReloadState {
  final String languageCode;
  final DateTime timestamp;

  const TranslationReloaded({
    required this.languageCode,
    required this.timestamp,
  });
}

/// State indicating that a theme file has been reloaded.
///
/// @param themeName:
///   - type: String
///   - description: The theme name that was reloaded.
/// @param timestamp:
///   - type: DateTime
///   - description: The timestamp when the reload occurred.
class ThemeReloaded extends JsonHotReloadState {
  final String themeName;
  final DateTime timestamp;

  const ThemeReloaded({required this.themeName, required this.timestamp});
}

/// State indicating that a configuration file has been reloaded.
///
/// @param timestamp:
///   - type: DateTime
///   - description: The timestamp when the reload occurred.
class ConfigurationReloaded extends JsonHotReloadState {
  final DateTime timestamp;

  const ConfigurationReloaded({required this.timestamp});
}

/// State indicating that all JSON files have been reloaded.
///
/// @param timestamp:
///   - type: DateTime
///   - description: The timestamp when the reload occurred.
class AllJsonFilesReloaded extends JsonHotReloadState {
  final DateTime timestamp;

  const AllJsonFilesReloaded({required this.timestamp});
}

/// State indicating an error occurred during file watching or reloading.
///
/// @param message:
///   - type: String
///   - description: The error message.
/// @param timestamp:
///   - type: DateTime
///   - description: The timestamp when the error occurred.
class JsonHotReloadError extends JsonHotReloadState {
  final String message;
  final DateTime timestamp;

  const JsonHotReloadError({required this.message, required this.timestamp});
}
