part of 'gateway_connection_bloc.dart';

sealed class GatewayConnectionEvent extends Equatable {
  const GatewayConnectionEvent();

  @override
  List<Object?> get props => [];
}

final class GatewayConnectionRequested extends GatewayConnectionEvent {
  const GatewayConnectionRequested({this.overrideUri});

  final Uri? overrideUri;

  @override
  List<Object?> get props => [overrideUri];
}

final class GatewayConnectionClosed extends GatewayConnectionEvent {
  const GatewayConnectionClosed();
}

final class _GatewayConnectionDropped extends GatewayConnectionEvent {
  const _GatewayConnectionDropped({
    this.error,
    this.stackTrace,
    this.remoteClose = false,
  });

  final Object? error;
  final StackTrace? stackTrace;
  final bool remoteClose;

  @override
  List<Object?> get props => [error, stackTrace, remoteClose];
}
