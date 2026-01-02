import 'dart:convert';

import 'package:http/http.dart' as http;

import '../backend_http_client.dart';

/// Repository for fetching acoustic materials from the backend.
class SimulationMaterialsRepository {
  SimulationMaterialsRepository({required BackendHttpClient httpClient})
    : _httpClient = httpClient;

  final BackendHttpClient _httpClient;

  /// Fetch all available acoustic materials.
  Future<List<AcousticMaterialDto>> fetchMaterials() async {
    final http.Response response = await _httpClient.get(
      '/v1/simulation/materials',
    );

    if (response.statusCode != 200) {
      throw BackendHttpException(
        'Failed to fetch acoustic materials',
        statusCode: response.statusCode,
        uri: Uri.parse('${_httpClient.baseUrl}/v1/simulation/materials'),
        body: response.body,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Materials payload must be an object');
    }

    final dynamic rawMaterials = decoded['materials'];
    if (rawMaterials is! List) {
      throw const FormatException('materials must be an array');
    }

    return rawMaterials
        .whereType<Map<String, dynamic>>()
        .map(AcousticMaterialDto.fromJson)
        .where((material) => material.isValid)
        .toList(growable: false);
  }
}

/// Data transfer object for an acoustic material.
class AcousticMaterialDto {
  AcousticMaterialDto({
    required this.id,
    required this.displayName,
    required this.absorption,
    required this.scattering,
  });

  factory AcousticMaterialDto.fromJson(Map<String, dynamic> json) {
    return AcousticMaterialDto(
      id: json['id']?.toString() ?? '',
      displayName:
          json['display_name']?.toString() ??
          json['displayName']?.toString() ??
          '',
      absorption: _asDouble(json['absorption']) ?? 0.0,
      scattering: _asDouble(json['scattering']) ?? 0.0,
    );
  }

  final String id;
  final String displayName;
  final double absorption;
  final double scattering;

  bool get isValid => id.isNotEmpty && displayName.isNotEmpty;

  @override
  String toString() =>
      'AcousticMaterialDto(id: $id, displayName: $displayName, absorption: $absorption)';
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
