import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

@immutable
class GatewayConfig {
  GatewayConfig({
    this.scheme = 'ws',
    this.host = '152.53.160.24',
    this.port = 8000,
    String path = '/ws',
    Map<String, String>? queryParameters,
    String? deviceId,
  }) : path = _normalizePath(path),
       queryParameters = Map.unmodifiable(
         queryParameters ?? const <String, String>{},
       ),
       deviceId = deviceId ?? _uuid.v4();

  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    final qp = <String, String>{};
    final rawParams = json['queryParameters'];
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        final dynamic rawKey = entry.key;
        final value = entry.value;
        if (rawKey == null || value == null) {
          continue;
        }
        final key = rawKey.toString();
        if (key.isEmpty) {
          continue;
        }
        qp[key] = value.toString();
      }
    }

    return GatewayConfig(
      scheme: (json['scheme'] as String?)?.trim().isNotEmpty == true
          ? json['scheme'] as String
          : 'ws',
      host: (json['host'] as String?)?.trim().isNotEmpty == true
          ? json['host'] as String
          : '152.53.160.24',
      port: _parsePort(json['port']) ?? 8000,
      path: (json['path'] as String?) ?? '/ws',
      queryParameters: qp,
      deviceId: (json['deviceId'] as String?)?.trim().isNotEmpty == true
          ? json['deviceId'] as String
          : null,
    );
  }

  static final Uuid _uuid = Uuid();

  final String scheme;
  final String host;
  final int? port;
  final String path;
  final Map<String, String> queryParameters;
  final String deviceId;

  /// Build a WebSocket URI for connecting to the gateway.
  Uri buildUri({String? deviceIdOverride, Map<String, String>? extras}) {
    final merged = <String, String>{...queryParameters};
    if (extras != null) {
      merged.addAll(extras);
    }
    merged['device_id'] = deviceIdOverride ?? deviceId;

    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: path,
      queryParameters: merged,
    );
  }

  /// Build the HTTP base URL for the gateway.
  ///
  /// All HTTP requests (audio download, file upload, etc.) go through the
  /// gateway which proxies them to the appropriate backend services.
  String buildHttpBaseUrl() {
    // Convert WebSocket scheme to HTTP scheme
    final httpScheme = scheme == 'wss' ? 'https' : 'http';

    // Build the base URL without the WebSocket path
    if (port != null) {
      return '$httpScheme://$host:$port';
    }
    return '$httpScheme://$host';
  }

  GatewayConfig copyWith({
    String? scheme,
    String? host,
    int? port,
    String? path,
    Map<String, String>? queryParameters,
    String? deviceId,
  }) {
    return GatewayConfig(
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      port: port ?? this.port,
      path: path ?? this.path,
      queryParameters: queryParameters ?? this.queryParameters,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'scheme': scheme,
    'host': host,
    'port': port,
    'path': path,
    'queryParameters': queryParameters,
    'deviceId': deviceId,
  };

  static int? _parsePort(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return int.tryParse(raw);
    }
    return null;
  }

  static String _normalizePath(String rawPath) {
    if (rawPath.isEmpty) {
      return '/ws';
    }
    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }
}
