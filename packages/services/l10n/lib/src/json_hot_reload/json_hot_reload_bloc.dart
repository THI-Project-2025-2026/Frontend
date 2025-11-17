import 'dart:async';
import 'dart:io';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:meta/meta.dart';
import '../app_constants.dart';
import '../l10n_asset_paths.dart';
part 'json_hot_reload_event.dart';
part 'json_hot_reload_state.dart';

/// Bloc for managing JSON file hot reload functionality.
///
/// This bloc watches JSON files for changes and automatically reloads them
/// when modifications are detected. It supports watching translation files,
/// theme files, and configuration files.
///
/// Note: On web builds, file system watching is disabled because `dart:io`
/// is not available in the browser. The bloc will emit
/// [JsonFileWatchingStopped] immediately when `StartFileWatching` is handled
/// on web, but manual reload events (e.g., [ReloadAllJsonFiles]) still work.
class JsonHotReloadBloc extends Bloc<JsonHotReloadEvent, JsonHotReloadState> {
  /// Timer for polling file system changes.
  Timer? _watchTimer;

  /// Map storing last modification times for watched files.
  final Map<String, DateTime> _lastModified = {};

  /// Set of currently watched file paths.
  final Set<String> _watchedFiles = {};

  /// Whether file watching is currently active.
  bool _isWatching = false;

  /// Currently active theme name (e.g., 'light', 'dark').
  String? _activeTheme;

  /// Currently active language code (e.g., 'en', 'es', 'de').
  String? _activeLanguage;

  /// Constructs a JsonHotReloadBloc.
  JsonHotReloadBloc() : super(const JsonHotReloadInitial()) {
    on<StartFileWatching>(_onStartFileWatching);
    on<StopFileWatching>(_onStopFileWatching);
    on<TranslationFileChanged>(_onTranslationFileChanged);
    on<ThemeFileChanged>(_onThemeFileChanged);
    on<ConfigurationFileChanged>(_onConfigurationFileChanged);
    on<ReloadAllJsonFiles>(_onReloadAllJsonFiles);
    on<ReloadLanguage>(_onReloadLanguage);
    on<ReloadTheme>(_onReloadTheme);
    on<SetActiveTheme>(_onSetActiveTheme);
    on<SetActiveLanguage>(_onSetActiveLanguage);

    // Initialize active settings from AppConstants
    _initializeActiveSettings();
  }

  /// Initializes the active theme and language from AppConstants.
  void _initializeActiveSettings() {
    try {
      _activeTheme = (AppConstants.config('defaultTheme') as String?) ?? 'dark';
      _activeLanguage =
          (AppConstants.config('defaultLanguage') as String?) ?? 'us';
    } catch (e) {
      log('Error initializing active settings: $e', name: 'JsonHotReloadBloc');
      // Fallback values
      _activeTheme = 'dark';
      _activeLanguage = 'us';
    }
  }

  /// Handles the SetActiveTheme event.
  ///
  /// Sets the currently active theme and updates the watched files.
  ///
  /// @param event:
  ///   - type: SetActiveTheme
  ///   - description: The event containing the theme name to set as active.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onSetActiveTheme(
    SetActiveTheme event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    if (_activeTheme != event.themeName) {
      _activeTheme = event.themeName;
      if (_isWatching) {
        // Update the watched files list
        _updateWatchedFiles();
        await _initializeLastModifiedTimes();
      }
      log('Active theme set to: ${event.themeName}', name: 'JsonHotReloadBloc');
    }
  }

  /// Handles the SetActiveLanguage event.
  ///
  /// Sets the currently active language and updates the watched files.
  ///
  /// @param event:
  ///   - type: SetActiveLanguage
  ///   - description: The event containing the language code to set as active.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onSetActiveLanguage(
    SetActiveLanguage event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    if (_activeLanguage != event.languageCode) {
      _activeLanguage = event.languageCode;
      if (_isWatching) {
        // Update the watched files list
        _updateWatchedFiles();
        await _initializeLastModifiedTimes();
      }
      log(
        'Active language set to: ${event.languageCode}',
        name: 'JsonHotReloadBloc',
      );
    }
  }

  /// Handles the StartFileWatching event.
  ///
  /// Begins watching JSON files for changes.
  ///
  /// @param event:
  ///   - type: StartFileWatching
  ///   - description: The event to handle.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  /// @returns:
  ///   - type: Future<void>
  ///   - description: Completes when the watching setup has been attempted.
  /// @throws:
  ///   - type: Exception
  ///   - description: Any unexpected error during initialization is logged and
  ///                  emitted via [JsonHotReloadError]; the exception does not
  ///                  propagate.
  Future<void> _onStartFileWatching(
    StartFileWatching event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      if (kIsWeb) {
        // File system watching is not supported on web; disable gracefully.
        log(
          'JSON file watching is disabled on web builds',
          name: 'JsonHotReloadBloc',
        );
        emit(const JsonFileWatchingStopped());
        return;
      }
      if (_isWatching) {
        return; // Already watching
      }

      // Add default files to watch list
      _updateWatchedFiles();

      // Initialize last modified times
      await _initializeLastModifiedTimes();

      // Start the polling timer
      _startPolling();

      _isWatching = true;
      emit(const JsonFileWatchingActive());

      log('JSON file watching started', name: 'JsonHotReloadBloc');
    } catch (e) {
      log('Error starting file watching: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to start file watching: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the StopFileWatching event.
  ///
  /// Stops watching JSON files for changes.
  ///
  /// @param event:
  ///   - type: StopFileWatching
  ///   - description: The event to handle.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onStopFileWatching(
    StopFileWatching event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    _stopWatching();
    emit(const JsonFileWatchingStopped());
    log('JSON file watching stopped', name: 'JsonHotReloadBloc');
  }

  /// Handles the TranslationFileChanged event.
  ///
  /// Reloads a translation file when it changes.
  ///
  /// @param event:
  ///   - type: TranslationFileChanged
  ///   - description: The event containing the changed file path.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onTranslationFileChanged(
    TranslationFileChanged event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      // Extract language code from file path
      final fileName = event.filePath.split('/').last.replaceAll('.json', '');

      // Reload the translation file
      await AppConstants.translation.importJson(
        event.filePath,
        assetPath: L10nAssetPaths.assetFromFilePath(event.filePath),
      );

      emit(
        TranslationReloaded(languageCode: fileName, timestamp: DateTime.now()),
      );

      log(
        'Translation file reloaded: ${event.filePath}',
        name: 'JsonHotReloadBloc',
      );
    } catch (e) {
      log('Error reloading translation file: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload translation file: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the ThemeFileChanged event.
  ///
  /// Reloads a theme file when it changes.
  ///
  /// @param event:
  ///   - type: ThemeFileChanged
  ///   - description: The event containing the changed file path.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onThemeFileChanged(
    ThemeFileChanged event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      // Extract theme name from file path
      final fileName = event.filePath.split('/').last.replaceAll('.json', '');

      // Reload the theme file
      await AppConstants.theme.importJson(
        event.filePath,
        assetPath: L10nAssetPaths.assetFromFilePath(event.filePath),
      );

      emit(ThemeReloaded(themeName: fileName, timestamp: DateTime.now()));

      log('Theme file reloaded: ${event.filePath}', name: 'JsonHotReloadBloc');
    } catch (e) {
      log('Error reloading theme file: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload theme file: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the ConfigurationFileChanged event.
  ///
  /// Reloads a configuration file when it changes.
  ///
  /// @param event:
  ///   - type: ConfigurationFileChanged
  ///   - description: The event containing the changed file path.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onConfigurationFileChanged(
    ConfigurationFileChanged event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      // Reload the configuration file
      await AppConstants.config.importJson(
        event.filePath,
        assetPath: L10nAssetPaths.assetFromFilePath(event.filePath),
      );

      emit(ConfigurationReloaded(timestamp: DateTime.now()));

      log(
        'Configuration file reloaded: ${event.filePath}',
        name: 'JsonHotReloadBloc',
      );
    } catch (e) {
      log('Error reloading configuration file: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload configuration file: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the ReloadAllJsonFiles event.
  ///
  /// Reloads all watched JSON files.
  ///
  /// @param event:
  ///   - type: ReloadAllJsonFiles
  ///   - description: The event to handle.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onReloadAllJsonFiles(
    ReloadAllJsonFiles event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      // Reinitialize AppConstants
      await AppConstants.initialize();

      emit(AllJsonFilesReloaded(timestamp: DateTime.now()));

      log('All JSON files reloaded', name: 'JsonHotReloadBloc');
    } catch (e) {
      log('Error reloading all JSON files: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload all JSON files: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the ReloadLanguage event.
  ///
  /// Reloads a specific language translation.
  ///
  /// @param event:
  ///   - type: ReloadLanguage
  ///   - description: The event containing the language code.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onReloadLanguage(
    ReloadLanguage event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      final translationPaths = L10nAssetPaths.translation(event.languageCode);
      await AppConstants.translation.importJson(
        translationPaths.file,
        assetPath: translationPaths.asset,
      );

      emit(
        TranslationReloaded(
          languageCode: event.languageCode,
          timestamp: DateTime.now(),
        ),
      );

      log(
        'Language reloaded: ${event.languageCode}',
        name: 'JsonHotReloadBloc',
      );
    } catch (e) {
      log('Error reloading language: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload language: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handles the ReloadTheme event.
  ///
  /// Reloads a specific theme.
  ///
  /// @param event:
  ///   - type: ReloadTheme
  ///   - description: The event containing the theme name.
  /// @param emit:
  ///   - type: Emitter<JsonHotReloadState>
  ///   - description: The emitter for state changes.
  Future<void> _onReloadTheme(
    ReloadTheme event,
    Emitter<JsonHotReloadState> emit,
  ) async {
    try {
      final themePaths = L10nAssetPaths.theme(event.themeName);
      await AppConstants.theme.importJson(
        themePaths.file,
        assetPath: themePaths.asset,
      );

      emit(
        ThemeReloaded(themeName: event.themeName, timestamp: DateTime.now()),
      );

      log('Theme reloaded: ${event.themeName}', name: 'JsonHotReloadBloc');
    } catch (e) {
      log('Error reloading theme: $e', name: 'JsonHotReloadBloc');
      emit(
        JsonHotReloadError(
          message: 'Failed to reload theme: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Updates the watched files list to only include currently active files.
  void _updateWatchedFiles() {
    _watchedFiles.clear();

    // Always watch configuration files
    _watchedFiles.add(L10nAssetPaths.defaultConfiguration().file);

    // Only watch the active theme file
    if (_activeTheme != null) {
      _watchedFiles.add(L10nAssetPaths.theme(_activeTheme!).file);
    }

    // Only watch the active translation file
    if (_activeLanguage != null) {
      _watchedFiles.add(L10nAssetPaths.translation(_activeLanguage!).file);
    }

    log('Updated watched files: $_watchedFiles', name: 'JsonHotReloadBloc');
  }

  /// Gets the currently active theme name.
  ///
  /// @returns:
  ///   - type: String?
  ///   - description: The currently active theme name, or null if not set.
  String? get activeTheme => _activeTheme;

  /// Gets the currently active language code.
  ///
  /// @returns:
  ///   - type: String?
  ///   - description: The currently active language code, or null if not set.
  String? get activeLanguage => _activeLanguage;

  /// Initializes the last modified times for all watched files.
  Future<void> _initializeLastModifiedTimes() async {
    for (final filePath in _watchedFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          _lastModified[filePath] = stat.modified;
        }
      } catch (e) {
        log(
          'Error getting file stats for $filePath: $e',
          name: 'JsonHotReloadBloc',
        );
      }
    }
  }

  /// Starts the polling timer to check for file changes.
  void _startPolling() {
    _watchTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkForFileChanges();
    });
  }

  /// Checks for file changes and dispatches appropriate events.
  Future<void> _checkForFileChanges() async {
    for (final filePath in _watchedFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          final lastModified = _lastModified[filePath];

          if (lastModified == null || stat.modified.isAfter(lastModified)) {
            _lastModified[filePath] = stat.modified;

            // Only dispatch events for files that are currently active
            if (filePath.contains(L10nAssetPaths.themesDirectory)) {
              final fileName = p.basenameWithoutExtension(filePath);
              if (fileName == _activeTheme) {
                add(ThemeFileChanged(filePath));
              }
            } else if (filePath.contains(
              L10nAssetPaths.translationsDirectory,
            )) {
              final fileName = p.basenameWithoutExtension(filePath);
              if (fileName == _activeLanguage) {
                add(TranslationFileChanged(filePath));
              }
            } else if (filePath.contains(
              L10nAssetPaths.configurationDirectory,
            )) {
              add(ConfigurationFileChanged(filePath));
            }
          }
        }
      } catch (e) {
        log('Error checking file $filePath: $e', name: 'JsonHotReloadBloc');
      }
    }
  }

  /// Stops the file watching system.
  void _stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
    _isWatching = false;
    _watchedFiles.clear();
    _lastModified.clear();
  }

  @override
  Future<void> close() async {
    _stopWatching();
    return super.close();
  }
}
