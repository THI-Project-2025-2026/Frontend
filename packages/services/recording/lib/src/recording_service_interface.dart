import 'package:record/record.dart';

/// Abstraction for an audio recorder that always returns raw, unprocessed data.
abstract class RecordingService {
  /// Ensures microphone permission is granted by the OS.
  Future<bool> hasPermission();

  /// Requests microphone permission from the OS.
  /// Returns true if permission was granted.
  Future<bool> requestPermission();

  /// Begins a new recording session writing raw audio into [filePath].
  Future<void> start({required String filePath});

  /// Stops the recording and resolves with the final file path.
  Future<String?> stop();

  /// Cancels the recording and discards any partial output.
  Future<void> cancel();

  /// Indicates whether the recorder is currently capturing audio.
  Future<bool> isRecording();

  /// Emits the raw amplitude of the captured signal at [interval].
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 200),
  });

  /// Releases the underlying recorder resources.
  Future<void> dispose();
}
