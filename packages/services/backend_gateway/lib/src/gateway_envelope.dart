import 'dart:convert';

class GatewayEnvelope {
  const GatewayEnvelope({
    required this.type,
    this.event,
    this.requestId,
    this.data,
    this.error,
  });

  final String type;
  final String? event;
  final String? requestId;
  final dynamic data;
  final dynamic error;

  bool get isResponse => type == 'response';
  bool get isEvent => type == 'event';
  bool get isError => type == 'error';

  static GatewayEnvelope? tryParse(dynamic raw) {
    try {
      final Map<String, dynamic>? map = _normalize(raw);
      if (map == null) {
        return null;
      }
      final type = map['type'] as String?;
      if (type == null || type.isEmpty) {
        return null;
      }
      return GatewayEnvelope(
        type: type,
        event: map['event'] as String?,
        requestId: map['request_id'] as String?,
        data: map['data'],
        error: map['error'],
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _normalize(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    return null;
  }
}
