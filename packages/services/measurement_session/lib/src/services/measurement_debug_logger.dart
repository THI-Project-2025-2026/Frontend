/// Debug logger for measurement sessions.
///
/// Provides detailed logging of all measurement-related events
/// that can be displayed in the UI and copied for debugging.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Log level for measurement debug entries.
enum MeasurementLogLevel { debug, info, warning, error }

/// A single log entry in the measurement debug log.
class MeasurementLogEntry {
  MeasurementLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final MeasurementLogLevel level;
  final String source;
  final String message;
  final Map<String, dynamic>? data;
  final Object? error;
  final StackTrace? stackTrace;

  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get levelIcon {
    switch (level) {
      case MeasurementLogLevel.debug:
        return '🔍';
      case MeasurementLogLevel.info:
        return 'ℹ️';
      case MeasurementLogLevel.warning:
        return '⚠️';
      case MeasurementLogLevel.error:
        return '❌';
    }
  }

  String get levelName {
    switch (level) {
      case MeasurementLogLevel.debug:
        return 'DEBUG';
      case MeasurementLogLevel.info:
        return 'INFO';
      case MeasurementLogLevel.warning:
        return 'WARN';
      case MeasurementLogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[$formattedTimestamp] [$levelName] [$source] $message');
    if (data != null && data!.isNotEmpty) {
      buffer.write('\n  Data: $data');
    }
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  Stack:\n$stackTrace');
    }
    return buffer.toString();
  }

  /// Format for display in UI (shorter version).
  String toDisplayString() {
    final buffer = StringBuffer();
    buffer.write('$levelIcon [$formattedTimestamp] [$source] $message');
    if (data != null && data!.isNotEmpty) {
      buffer.write('\n     Data: $data');
    }
    if (error != null) {
      buffer.write('\n     Error: $error');
    }
    return buffer.toString();
  }
}

/// Debug logger for measurement sessions.
///
/// This logger captures all measurement-related events and provides
/// methods to retrieve and export the log for debugging purposes.
class MeasurementDebugLogger {
  MeasurementDebugLogger._internal();

  static final MeasurementDebugLogger _instance =
      MeasurementDebugLogger._internal();

  /// Get the singleton instance.
  static MeasurementDebugLogger get instance => _instance;

  final List<MeasurementLogEntry> _entries = [];
  final _controller = StreamController<MeasurementLogEntry>.broadcast();
  static const int _maxEntries = 1000;

  /// Stream of new log entries.
  Stream<MeasurementLogEntry> get stream => _controller.stream;

  /// Get all log entries.
  List<MeasurementLogEntry> get entries => List.unmodifiable(_entries);

  /// Clear all log entries.
  void clear() {
    _entries.clear();
  }

  /// Log a debug message.
  void debug(String source, String message, {Map<String, dynamic>? data}) {
    _log(MeasurementLogLevel.debug, source, message, data: data);
  }

  /// Log an info message.
  void info(String source, String message, {Map<String, dynamic>? data}) {
    _log(MeasurementLogLevel.info, source, message, data: data);
  }

  /// Log a warning message.
  void warning(String source, String message, {Map<String, dynamic>? data}) {
    _log(MeasurementLogLevel.warning, source, message, data: data);
  }

  /// Log an error message.
  void error(
    String source,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      MeasurementLogLevel.error,
      source,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    MeasurementLogLevel level,
    String source,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = MeasurementLogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    _entries.add(entry);

    // Trim old entries if we exceed the limit
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }

    _controller.add(entry);

    // Also log to debug console
    debugPrint(entry.toString());
  }

  /// Export all logs as a single string suitable for copying.
  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== Measurement Debug Log ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_entries.length}');
    buffer.writeln('');
    buffer.writeln('=== Log Entries ===');

    for (final entry in _entries) {
      buffer.writeln(entry.toString());
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// Export logs filtered by source.
  String exportLogsBySource(String source) {
    final filtered = _entries.where((e) => e.source == source).toList();
    final buffer = StringBuffer();
    buffer.writeln('=== Measurement Debug Log (Source: $source) ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${filtered.length}');
    buffer.writeln('');

    for (final entry in filtered) {
      buffer.writeln(entry.toString());
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// Get a summary of log levels.
  Map<MeasurementLogLevel, int> getSummary() {
    final summary = <MeasurementLogLevel, int>{};
    for (final level in MeasurementLogLevel.values) {
      summary[level] = _entries.where((e) => e.level == level).length;
    }
    return summary;
  }

  /// Dispose resources.
  void dispose() {
    _controller.close();
  }
}
