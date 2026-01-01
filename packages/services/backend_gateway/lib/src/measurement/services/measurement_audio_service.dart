import 'package:flutter/foundation.dart';

import '../../backend_http_client.dart';
import '../models/measurement_session_models.dart';

/// Service for measurement audio operations.
///
/// Handles fetching audio metadata and uploading recordings.
/// All HTTP requests are delegated to [BackendHttpClient].
class MeasurementAudioService {
  MeasurementAudioService({required BackendHttpClient httpClient})
    : _httpClient = httpClient;

  final BackendHttpClient _httpClient;

  /// Fetch information about the measurement audio signal.
  Future<MeasurementAudioInfo> getAudioInfo({int sampleRate = 48000}) async {
    debugPrint('[MeasurementAudioService] Fetching audio info');

    final json = await _httpClient.getMeasurementAudioInfo(
      sampleRate: sampleRate,
    );
    return MeasurementAudioInfo.fromJson(json);
  }

  /// Get the URL for downloading measurement audio.
  String getAudioDownloadUrl({
    String? sessionId,
    int sampleRate = 48000,
    String format = 'wav',
  }) {
    return _httpClient
        .getMeasurementAudioUri(
          sessionId: sessionId,
          sampleRate: sampleRate,
          format: format,
        )
        .toString();
  }

  /// Upload a recording file to the measurement job.
  ///
  /// [jobId] - The job ID to upload to
  /// [uploadName] - Name for the upload (e.g., "recording_mic1_speaker1")
  /// [filePath] - Path to the recording file
  Future<Map<String, dynamic>> uploadRecording({
    required String jobId,
    required String uploadName,
    required String filePath,
  }) async {
    debugPrint('[MeasurementAudioService] Uploading recording: $uploadName');

    return _httpClient.uploadRecordingFile(
      jobId: jobId,
      uploadName: uploadName,
      filePath: filePath,
    );
  }

  /// Upload recording bytes directly.
  Future<Map<String, dynamic>> uploadRecordingBytes({
    required String jobId,
    required String uploadName,
    required List<int> bytes,
  }) async {
    debugPrint(
      '[MeasurementAudioService] Uploading recording bytes: $uploadName',
    );

    return _httpClient.uploadRecordingBytes(
      jobId: jobId,
      uploadName: uploadName,
      bytes: bytes,
    );
  }

  void dispose() {
    // BackendHttpClient lifecycle is managed externally
  }
}
