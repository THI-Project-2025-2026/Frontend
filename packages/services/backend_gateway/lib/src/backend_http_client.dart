import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gateway_config.dart';

/// HTTP client for making requests to backend services through the gateway.
///
/// All HTTP requests (audio download, file uploads, etc.) are routed through
/// the gateway, which proxies them to the appropriate internal services.
class BackendHttpClient {
  BackendHttpClient({required GatewayConfig config, http.Client? httpClient})
    : _baseUrl = config.buildHttpBaseUrl(),
      _client = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// The base URL for HTTP requests to the gateway.
  String get baseUrl => _baseUrl;

  // ============================================================
  // Measurement Audio API
  // ============================================================

  /// Get the URL for downloading measurement audio.
  ///
  /// Returns a URL that can be used directly for audio playback on web,
  /// or for downloading the file on native platforms.
  Uri getMeasurementAudioUri({
    String? sessionId,
    int sampleRate = 48000,
    String format = 'wav',
  }) {
    return Uri.parse('$_baseUrl/v1/measurement/audio').replace(
      queryParameters: {
        if (sessionId != null) 'session_id': sessionId,
        'sample_rate': sampleRate.toString(),
        'format': format,
      },
    );
  }

  /// Download measurement audio bytes from the backend.
  ///
  /// Returns a [DownloadedAudio] containing the audio bytes and validation info.
  /// Throws an exception if the download fails or hash validation fails.
  Future<DownloadedAudio> downloadMeasurementAudio({
    String? sessionId,
    int sampleRate = 48000,
  }) async {
    final uri = getMeasurementAudioUri(
      sessionId: sessionId,
      sampleRate: sampleRate,
    );

    debugPrint('[BackendHttpClient] Downloading measurement audio from: $uri');

    final response = await _client.get(uri);

    debugPrint('[BackendHttpClient] Response status: ${response.statusCode}');
    debugPrint(
      '[BackendHttpClient] Response body length: ${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      throw BackendHttpException(
        'Failed to download audio',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    // Validate Hash
    final receivedHash = response.headers['x-audio-hash'];
    final bytes = response.bodyBytes;
    final calculatedHash = sha256.convert(bytes).toString();

    debugPrint('[BackendHttpClient] Audio Validation:');
    debugPrint('  File size: ${bytes.length} bytes');
    debugPrint('  Received Hash: $receivedHash');
    debugPrint('  Calculated Hash: $calculatedHash');

    if (receivedHash != null && receivedHash != calculatedHash) {
      debugPrint('  Result: INVALID HASH');
      throw BackendHttpException(
        'Audio hash validation failed. Received: $receivedHash, Calculated: $calculatedHash',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    debugPrint(
      '  Result: ${receivedHash == null ? "NO HASH RECEIVED (Skipping validation)" : "VALID"}',
    );

    return DownloadedAudio(
      bytes: bytes,
      receivedHash: receivedHash,
      calculatedHash: calculatedHash,
    );
  }

  /// Fetch information about the measurement audio signal.
  Future<Map<String, dynamic>> getMeasurementAudioInfo({
    int sampleRate = 48000,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/measurement/audio/info',
    ).replace(queryParameters: {'sample_rate': sampleRate.toString()});

    debugPrint('[BackendHttpClient] Fetching audio info from: $uri');

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw BackendHttpException(
        'Failed to get audio info',
        statusCode: response.statusCode,
        uri: uri,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ============================================================
  // Job Uploads API
  // ============================================================

  /// Upload a recording file to a measurement job.
  ///
  /// [jobId] - The job ID to upload to
  /// [uploadName] - Name for the upload (e.g., "recording_mic1_speaker1.wav")
  /// [filePath] - Path to the recording file on disk
  Future<Map<String, dynamic>> uploadRecordingFile({
    required String jobId,
    required String uploadName,
    required String filePath,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/jobs/$jobId/uploads/$uploadName');

    debugPrint('[BackendHttpClient] Uploading recording to: $uri');

    final file = File(filePath);
    if (!await file.exists()) {
      throw BackendHttpException(
        'Recording file not found: $filePath',
        statusCode: 0,
        uri: uri,
      );
    }

    final bytes = await file.readAsBytes();
    return uploadRecordingBytes(
      jobId: jobId,
      uploadName: uploadName,
      bytes: bytes,
    );
  }

  /// Upload recording bytes directly to a measurement job.
  ///
  /// [jobId] - The job ID to upload to
  /// [uploadName] - Name for the upload (e.g., "recording_mic1_speaker1.wav")
  /// [bytes] - The raw audio bytes
  Future<Map<String, dynamic>> uploadRecordingBytes({
    required String jobId,
    required String uploadName,
    required List<int> bytes,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/jobs/$jobId/uploads/$uploadName');

    debugPrint('[BackendHttpClient] Uploading recording bytes to: $uri');
    debugPrint('[BackendHttpClient] Upload size: ${bytes.length} bytes');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: uploadName),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw BackendHttpException(
        'Failed to upload recording',
        statusCode: response.statusCode,
        uri: uri,
        body: response.body,
      );
    }

    debugPrint('[BackendHttpClient] Upload successful');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ============================================================
  // Generic HTTP Methods
  // ============================================================

  /// Perform a GET request to a backend endpoint.
  Future<http.Response> get(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    debugPrint('[BackendHttpClient] GET $uri');
    return _client.get(uri);
  }

  /// Perform a POST request to a backend endpoint.
  Future<http.Response> post(
    String path, {
    Map<String, String>? queryParams,
    Object? body,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    debugPrint('[BackendHttpClient] POST $uri');
    return _client.post(
      uri,
      body: body is Map || body is List ? jsonEncode(body) : body,
      headers: {
        if (body is Map || body is List) 'Content-Type': 'application/json',
        ...?headers,
      },
    );
  }

  /// Close the HTTP client and release resources.
  void dispose() {
    _client.close();
  }
}

/// Result of downloading audio from the backend.
class DownloadedAudio {
  const DownloadedAudio({
    required this.bytes,
    this.receivedHash,
    this.calculatedHash,
  });

  /// The raw audio bytes.
  final Uint8List bytes;

  /// The hash received from the server (may be null).
  final String? receivedHash;

  /// The locally calculated SHA-256 hash of the bytes.
  final String? calculatedHash;

  /// Whether the hash was validated successfully.
  bool get isHashValid =>
      receivedHash == null || receivedHash == calculatedHash;
}

/// Exception thrown when a backend HTTP request fails.
class BackendHttpException implements Exception {
  const BackendHttpException(
    this.message, {
    required this.statusCode,
    required this.uri,
    this.body,
  });

  final String message;
  final int statusCode;
  final Uri uri;
  final String? body;

  @override
  String toString() =>
      'BackendHttpException: $message (status=$statusCode, uri=$uri)';
}
