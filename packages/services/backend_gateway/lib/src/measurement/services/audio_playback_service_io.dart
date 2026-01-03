// Native (iOS, Android, macOS, Windows, Linux) implementation for audio file operations.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Save audio bytes to a temporary file.
Future<String> saveAudioToFile(Uint8List bytes, String? sessionId) async {
  final tempDir = await getTemporaryDirectory();
  final fileName = sessionId != null
      ? 'measurement_$sessionId.wav'
      : 'measurement_audio.wav';
  final filePath = '${tempDir.path}/$fileName';

  final file = File(filePath);
  await file.writeAsBytes(bytes);

  return filePath;
}

/// Delete an audio file.
Future<void> deleteAudioFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    debugPrint('[AudioPlaybackService] Failed to delete cached audio: $e');
  }
}
