import 'package:record/record.dart';

import '../recording_service_interface.dart';

/// Exception thrown when microphone permission is missing.
class RecordingPermissionException implements Exception {
  RecordingPermissionException(this.platformLabel);

  final String platformLabel;

  @override
  String toString() =>
      'RecordingPermissionException: Microphone permission denied on $platformLabel';
}

/// Common skeleton that wires the [AudioRecorder] with a raw [RecordConfig].
abstract class RawRecordingService implements RecordingService {
  RawRecordingService(this.platformLabel);

  final String platformLabel;
  final AudioRecorder _recorder = AudioRecorder();

  /// Platform specific modifiers for a raw config.
  RecordConfig buildConfig();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start({required String filePath}) async {
    if (filePath.isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'must not be empty');
    }

    final granted = await _recorder.hasPermission();
    if (!granted) {
      throw RecordingPermissionException(platformLabel);
    }

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    await _recorder.start(buildConfig(), path: filePath);
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 200),
  }) => _recorder.onAmplitudeChanged(interval);

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Shared helper that disables every post processing feature and records WAV.
RecordConfig rawRecordConfig({
  AndroidRecordConfig? androidConfig,
  IosRecordConfig? iosConfig,
}) => RecordConfig(
  encoder: AudioEncoder.wav,
  bitRate: 1536000,
  sampleRate: 48000,
  numChannels: 2,
  autoGain: false,
  echoCancel: false,
  noiseSuppress: false,
  androidConfig: androidConfig ?? const AndroidRecordConfig(),
  iosConfig: iosConfig ?? const IosRecordConfig(),
);
