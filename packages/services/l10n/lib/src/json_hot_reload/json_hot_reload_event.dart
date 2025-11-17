part of 'json_hot_reload_bloc.dart';

/// Base class for JSON hot reload events.
///
/// This sealed class defines all possible events that can be dispatched
/// to the JsonHotReloadBloc to trigger JSON file reloading.
@immutable
sealed class JsonHotReloadEvent {}

/// Event dispatched to initialize JSON file watching.
class StartFileWatching extends JsonHotReloadEvent {}

/// Event dispatched to stop JSON file watching.
class StopFileWatching extends JsonHotReloadEvent {}

/// Event dispatched when a translation file changes.
///
/// @param filePath:
///   - type: String
///   - description: The path of the changed translation file.
class TranslationFileChanged extends JsonHotReloadEvent {
  final String filePath;
  TranslationFileChanged(this.filePath);
}

/// Event dispatched when a theme file changes.
///
/// @param filePath:
///   - type: String
///   - description: The path of the changed theme file.
class ThemeFileChanged extends JsonHotReloadEvent {
  final String filePath;
  ThemeFileChanged(this.filePath);
}

/// Event dispatched when a configuration file changes.
///
/// @param filePath:
///   - type: String
///   - description: The path of the changed configuration file.
class ConfigurationFileChanged extends JsonHotReloadEvent {
  final String filePath;
  ConfigurationFileChanged(this.filePath);
}

/// Event dispatched to manually reload all JSON files.
class ReloadAllJsonFiles extends JsonHotReloadEvent {}

/// Event dispatched to reload a specific language translation.
///
/// @param languageCode:
///   - type: String
///   - description: The language code to reload (e.g., 'en', 'es', 'de').
class ReloadLanguage extends JsonHotReloadEvent {
  final String languageCode;
  ReloadLanguage(this.languageCode);
}

/// Event dispatched to reload a specific theme.
///
/// @param themeName:
///   - type: String
///   - description: The theme name to reload (e.g., 'light', 'dark').
class ReloadTheme extends JsonHotReloadEvent {
  final String themeName;
  ReloadTheme(this.themeName);
}

/// Event dispatched to set the active theme for watching.
///
/// @param themeName:
///   - type: String
///   - description: The theme name to set as active (e.g., 'light', 'dark').
class SetActiveTheme extends JsonHotReloadEvent {
  final String themeName;
  SetActiveTheme(this.themeName);
}

/// Event dispatched to set the active language for watching.
///
/// @param languageCode:
///   - type: String
///   - description: The language code to set as active (e.g., 'en', 'es', 'de').
class SetActiveLanguage extends JsonHotReloadEvent {
  final String languageCode;
  SetActiveLanguage(this.languageCode);
}
