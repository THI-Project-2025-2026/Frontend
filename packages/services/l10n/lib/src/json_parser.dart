import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

/// A parser for JSON-based translations and themes.
///
/// This class dynamically adapts to the structure of the JSON file, allowing
/// access to its keys using dot-separated strings. For example, if the JSON contains:
///
/// {
///   "general": {
///     "helloworld": "Hello, World!"
///   }
/// }
///
/// You can access the string "Hello, World!" like this:
///
/// jsonParser("general.helloworld");
class JsonParser {
  /// The root of the parsed JSON tree.
  final Map<String, dynamic> _data = {};

  /// Constructs an empty [JsonParser] instance.
  ///
  /// The JSON tree can be populated using the [importJson] method.
  JsonParser();

  /// Imports and merges a JSON file into the existing JSON tree.
  ///
  /// This method is web-safe. On web, it loads JSON from bundled assets using
  /// `rootBundle`. On mobile/desktop, it first attempts to read from the local
  /// file system so JSON edits are visible without a rebuild, then falls back to
  /// bundled assets. When [assetPath] is omitted, [filePath] is reused for both.
  ///
  /// @param filePath:
  ///   - type: String
  ///   - description: The absolute or relative file-system path used for the
  ///                  initial disk read.
  /// @param assetPath:
  ///   - type: String?
  ///   - description: Optional Flutter asset path to use when disk reads fail
  ///                  or when running on the web.
  /// @returns:
  ///   - type: Future<void>
  ///   - description: A future that completes when the JSON has been merged.
  /// @throws:
  ///   - type: Exception
  ///   - description: If the content cannot be read from assets or file system,
  ///                  or the content is not valid JSON.
  Future<void> importJson(String filePath, {String? assetPath}) async {
    // On non-web platforms, prefer reading directly from the file system so
    // edits are reflected immediately during development (hot reload/watch).
    // On web, use assets (no file system). On non-web, if file read fails,
    // fall back to assets to support packaged builds.
    String jsonString;
    final bundlePath = assetPath ?? filePath;
    if (!kIsWeb) {
      try {
        jsonString = await File(filePath).readAsString();
      } catch (fsError) {
        try {
          jsonString = await rootBundle.loadString(bundlePath);
        } catch (assetError) {
          log(
            'JsonParser: Failed to read JSON from file and assets. '
            'fsError=$fsError, assetError=$assetError, path="$filePath"',
            name: 'JsonParser',
          );
          rethrow;
        }
      }
    } else {
      try {
        jsonString = await rootBundle.loadString(bundlePath);
      } catch (assetError) {
        log(
          'JsonParser: Failed to load JSON asset "$bundlePath": $assetError',
          name: 'JsonParser',
        );
        rethrow;
      }
    }

    // Parse and merge the JSON content into the internal map.
    try {
      final Map<String, dynamic> newData = jsonDecode(jsonString);
      _mergeMaps(_data, newData);
    } catch (e) {
      log(
        'JsonParser: Failed to parse JSON from "$filePath": $e',
        name: 'JsonParser',
      );
      rethrow;
    }
  }

  /// Merges [source] into [target], overwriting existing keys and adding new ones.
  ///
  /// @param target:
  ///   - type: Map<String, dynamic>
  ///   - description: The target map to merge into.
  /// @param source:
  ///   - type: Map<String, dynamic>
  ///   - description: The source map to merge from.
  void _mergeMaps(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          target[key] is Map<String, dynamic>) {
        _mergeMaps(target[key] as Map<String, dynamic>, value);
      } else {
        target[key] = value;
      }
    });
  }

  /// Retrieves a value from the JSON tree using a dot-separated key.
  ///
  /// @param keyPath:
  ///   - type: String
  ///   - description: The dot-separated key path to retrieve from the JSON tree.
  /// @returns:
  ///   - type: dynamic
  ///   - description: The value associated with the key path, or null if not found.
  dynamic call(String keyPath) {
    final keys = keyPath.split('.');
    dynamic current = _data;

    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        log(
          'JsonParser: Key path "$keyPath" does not exist',
          name: 'JsonParser',
        );
        return ""; // Key path does not exist.
      }
    }

    return current;
  }
}
