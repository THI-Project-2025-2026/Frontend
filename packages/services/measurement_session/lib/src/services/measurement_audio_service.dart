import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/measurement_session_models.dart';

/// Service for measurement audio operations.
///
/// Handles fetching audio metadata and uploading recordings.
class MeasurementAudioService {
  MeasurementAudioService({required this.baseUrl, http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Fetch information about the measurement audio signal.
  Future<MeasurementAudioInfo> getAudioInfo({int sampleRate = 48000}) async {
    final uri = Uri.parse(
      '$baseUrl/v1/measurement/audio/info',
    ).replace(queryParameters: {'sample_rate': sampleRate.toString()});

    debugPrint('Fetching audio info from: $uri');

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get audio info: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return MeasurementAudioInfo.fromJson(json);
  }

  /// Get the URL for downloading measurement audio.
  String getAudioDownloadUrl({
    String? sessionId,
    int sampleRate = 48000,
    String format = 'wav',
  }) {
    final uri = Uri.parse('$baseUrl/v1/measurement/audio').replace(
      queryParameters: {
        if (sessionId != null) 'session_id': sessionId,
        'sample_rate': sampleRate.toString(),
        'format': format,
      },
    );
    return uri.toString();
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
    final uri = Uri.parse('$baseUrl/v1/jobs/$jobId/uploads/$uploadName');

    debugPrint('Uploading recording to: $uri');

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Recording file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: uploadName),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Failed to upload recording: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Upload recording bytes directly.
  Future<Map<String, dynamic>> uploadRecordingBytes({
    required String jobId,
    required String uploadName,
    required List<int> bytes,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/jobs/$jobId/uploads/$uploadName');

    debugPrint('Uploading recording bytes to: $uri');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: uploadName),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Failed to upload recording: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
}
