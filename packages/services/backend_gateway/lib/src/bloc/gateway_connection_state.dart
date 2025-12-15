part of 'gateway_connection_bloc.dart';

enum GatewayConnectionStatus {
  initial,
  connecting,
  connected,
  disconnected,
  failure,
}

class GatewayConnectionState extends Equatable {
  const GatewayConnectionState({
    required this.status,
    required this.uri,
    this.lastError,
  });

  factory GatewayConnectionState.initial(Uri uri) =>
      GatewayConnectionState(status: GatewayConnectionStatus.initial, uri: uri);

  final GatewayConnectionStatus status;
  final Uri uri;
  final String? lastError;

  GatewayConnectionState copyWith({
    GatewayConnectionStatus? status,
    Uri? uri,
    String? lastError,
    bool clearError = false,
  }) {
    return GatewayConnectionState(
      status: status ?? this.status,
      uri: uri ?? this.uri,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [status, uri, lastError];
}
