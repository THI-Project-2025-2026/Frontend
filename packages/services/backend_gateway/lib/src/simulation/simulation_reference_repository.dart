import 'dart:convert';

import 'package:http/http.dart' as http;

import '../backend_http_client.dart';

class SimulationReferenceRepository {
  SimulationReferenceRepository({required BackendHttpClient httpClient})
    : _httpClient = httpClient;

  final BackendHttpClient _httpClient;

  Future<List<SimulationReferenceProfileDto>> fetchReferenceProfiles() async {
    final http.Response response = await _httpClient.get(
      '/v1/simulation/reference-profiles',
    );

    if (response.statusCode != 200) {
      throw BackendHttpException(
        'Failed to fetch simulation reference profiles',
        statusCode: response.statusCode,
        uri: Uri.parse(
          '${_httpClient.baseUrl}/v1/simulation/reference-profiles',
        ),
        body: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Reference profile payload must be an object',
      );
    }

    final dynamic rawProfiles = decoded['profiles'];
    if (rawProfiles is! List) {
      throw const FormatException('profiles must be an array');
    }

    return rawProfiles
        .whereType<Map<String, dynamic>>()
        .map(SimulationReferenceProfileDto.fromJson)
        .where((profile) => profile.isValid)
        .toList(growable: false);
  }
}

class SimulationReferenceProfileDto {
  SimulationReferenceProfileDto({
    required this.id,
    required this.displayName,
    required this.metrics,
    this.notes,
  });

  factory SimulationReferenceProfileDto.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];
    final metrics = rawMetrics is List
        ? rawMetrics
              .whereType<Map<String, dynamic>>()
              .map(SimulationReferenceMetricDto.fromJson)
              .where((metric) => metric.isValid)
              .toList(growable: false)
        : const <SimulationReferenceMetricDto>[];
    return SimulationReferenceProfileDto(
      id: json['id']?.toString() ?? '',
      displayName:
          json['display_name']?.toString() ??
          json['displayName']?.toString() ??
          '',
      metrics: metrics,
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String displayName;
  final List<SimulationReferenceMetricDto> metrics;
  final String? notes;

  bool get isValid =>
      id.isNotEmpty && displayName.isNotEmpty && metrics.isNotEmpty;
}

class SimulationReferenceMetricDto {
  const SimulationReferenceMetricDto({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.minValue,
    this.maxValue,
  });

  factory SimulationReferenceMetricDto.fromJson(Map<String, dynamic> json) {
    return SimulationReferenceMetricDto(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: _asDouble(json['value']),
      unit: json['unit']?.toString(),
      minValue: _asDouble(json['min_value'] ?? json['minValue']),
      maxValue: _asDouble(json['max_value'] ?? json['maxValue']),
    );
  }

  final String key;
  final String label;
  final double? value;
  final String? unit;
  final double? minValue;
  final double? maxValue;

  bool get isValid => key.isNotEmpty && label.isNotEmpty && value != null;
}

double? _asDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
