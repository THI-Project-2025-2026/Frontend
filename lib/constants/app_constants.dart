import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sonalyze_frontend/l10n/json_parser.dart';

/// Application-wide constants
///
/// This class contains constants used throughout the application.
class AppConstants {
  /// Retrieves a single color from the theme JSON given a dot-separated key path.
  static Color getThemeColor(String keyPath) {
    final value = theme.call(keyPath);
    if (value is String) {
      try {
        return _hexToColor(value);
      } catch (e) {
        log(
          'AppConstants: Invalid color format "$value" for key path "$keyPath"',
          name: 'AppConstants',
        );
        return const Color(0x00000000);
      }
    }
    // Log when the key path doesn't exist or isn't a string
    if (value == null) {
      log(
        'AppConstants: Color key path "$keyPath" not found in theme',
        name: 'AppConstants',
      );
    } else {
      log(
        'AppConstants: Color key path "$keyPath" is not a string (got ${value.runtimeType})',
        name: 'AppConstants',
      );
    }
    // Fallback to transparent if not found or invalid.
    return const Color(0x00000000);
  }

  /// Retrieves a list of colors from the theme JSON given a dot-separated key path.
  static List<Color> getThemeColors(String keyPath) {
    final value = theme.call(keyPath);
    if (value is List) {
      return value.map<Color>((e) {
        if (e is String) {
          try {
            return _hexToColor(e);
          } catch (error) {
            log(
              'AppConstants: Invalid color format "$e" in list for key path "$keyPath"',
              name: 'AppConstants',
            );
            return const Color(0x00000000);
          }
        }
        log(
          'AppConstants: Non-string color value "$e" in list for key path "$keyPath"',
          name: 'AppConstants',
        );
        return const Color(0x00000000);
      }).toList();
    }
    // Log when the key path doesn't exist or isn't a list
    if (value == null) {
      log(
        'AppConstants: Color list key path "$keyPath" not found in theme',
        name: 'AppConstants',
      );
    } else {
      log(
        'AppConstants: Color list key path "$keyPath" is not a list (got ${value.runtimeType})',
        name: 'AppConstants',
      );
    }
    return <Color>[];
  }

  /// Parses a hexadecimal color string and returns a [Color].
  static Color _hexToColor(String hex) {
    if (hex.isEmpty) {
      throw FormatException('Color string cannot be empty');
    }

    var cleaned = hex.replaceFirst('#', '');

    // Validate hex string contains only valid hex characters
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(cleaned)) {
      throw FormatException('Invalid hex color format: "$hex"');
    }

    // If RGBA (8 chars), convert to ARGB for Flutter
    if (cleaned.length == 8) {
      // RRGGBBAA -> AARRGGBB
      cleaned = cleaned.substring(6, 8) + cleaned.substring(0, 6);
    } else if (cleaned.length == 6) {
      // assume RGB, add full opacity
      cleaned = 'FF$cleaned';
    } else {
      throw FormatException(
        'Invalid hex color length: "$hex" (expected 6 or 8 characters)',
      );
    }

    try {
      return Color(int.parse(cleaned, radix: 16));
    } catch (e) {
      throw FormatException('Failed to parse hex color: "$hex"');
    }
  }

  /// The JSON parser for the application's configuration.
  ///
  /// This parser loads and provides access to the default configuration settings.
  static final JsonParser config = JsonParser();

  /// The JSON parser for the application's theme.
  ///
  /// This parser loads and provides access to the default theme settings.
  static final JsonParser theme = JsonParser();

  /// The JSON parser for the application's translations.
  ///
  /// This parser loads and provides access to the default language translations.
  static final JsonParser translation = JsonParser();

  /// Initializes the application constants by loading the default configuration,
  /// theme, and translation files.
  ///
  /// @returns:
  ///   - type: Future<void>
  ///   - description: A future that completes when all files are loaded.
  static Future<void> initialize() async {
    // Load default configuration
    await config.importJson(
      'lib/l10n/configuration/default_configuration.json',
    );

    // Load default theme
    final defaultTheme = config('defaultTheme') as String;
    await theme.importJson('lib/l10n/themes/$defaultTheme.json');

    // Load default translation
    final defaultLanguage = config('defaultLanguage') as String;
    await translation.importJson('lib/l10n/translations/$defaultLanguage.json');
  }
}
