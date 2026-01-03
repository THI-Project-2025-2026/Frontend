// Web implementation for audio file operations.
// On web, file operations are not needed since we use in-memory bytes.
import 'dart:typed_data';

/// Save audio bytes to a temporary file (no-op on web).
Future<String> saveAudioToFile(Uint8List bytes, String? sessionId) async {
  // On web, we don't save to file - audio is played from memory
  return 'web-audio-bytes';
}

/// Delete an audio file (no-op on web).
Future<void> deleteAudioFile(String path) async {
  // No file to delete on web
}
