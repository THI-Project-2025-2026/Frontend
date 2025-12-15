import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../gateway_config.dart';
import '../gateway_connection_repository.dart';

part 'gateway_connection_event.dart';
part 'gateway_connection_state.dart';

class GatewayConnectionBloc
    extends Bloc<GatewayConnectionEvent, GatewayConnectionState> {
  GatewayConnectionBloc({
    required GatewayConfig config,
    required GatewayConnectionRepository repository,
  }) : _config = config,
       _repository = repository,
       super(GatewayConnectionState.initial(config.buildUri())) {
    on<GatewayConnectionRequested>(_onConnectionRequested);
    on<GatewayConnectionClosed>(_onConnectionClosed);
    on<_GatewayConnectionDropped>(_onConnectionDropped);
  }

  final GatewayConfig _config;
  final GatewayConnectionRepository _repository;
  StreamSubscription? _channelSubscription;

  Future<void> _onConnectionRequested(
    GatewayConnectionRequested event,
    Emitter<GatewayConnectionState> emit,
  ) async {
    final targetUri = event.overrideUri ?? _config.buildUri();
    emit(
      state.copyWith(
        status: GatewayConnectionStatus.connecting,
        uri: targetUri,
        clearError: true,
      ),
    );

    await _channelSubscription?.cancel();
    try {
      final channel = await _repository.connect(targetUri);
      _channelSubscription = channel.stream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => add(
          _GatewayConnectionDropped(error: error, stackTrace: stackTrace),
        ),
        onDone: () => add(const _GatewayConnectionDropped(remoteClose: true)),
        cancelOnError: false,
      );

      debugPrint('Gateway connection established @ $targetUri');
      emit(
        state.copyWith(
          status: GatewayConnectionStatus.connected,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Gateway connection failed: $error');
      await _repository.close();
      emit(
        state.copyWith(
          status: GatewayConnectionStatus.failure,
          lastError: error.toString(),
        ),
      );
      addError(error, stackTrace);
    }
  }

  Future<void> _onConnectionClosed(
    GatewayConnectionClosed event,
    Emitter<GatewayConnectionState> emit,
  ) async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _repository.close();
    emit(
      state.copyWith(
        status: GatewayConnectionStatus.disconnected,
        clearError: true,
      ),
    );
  }

  Future<void> _onConnectionDropped(
    _GatewayConnectionDropped event,
    Emitter<GatewayConnectionState> emit,
  ) async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _repository.close();

    if (event.error != null) {
      debugPrint('Gateway connection lost: ${event.error}');
      emit(
        state.copyWith(
          status: GatewayConnectionStatus.failure,
          lastError: event.error.toString(),
        ),
      );
      if (event.stackTrace != null) {
        addError(event.error!, event.stackTrace!);
      }
    } else {
      final message = event.remoteClose
          ? 'Gateway connection closed by remote peer.'
          : 'Gateway connection closed.';
      debugPrint(message);
      emit(
        state.copyWith(
          status: GatewayConnectionStatus.disconnected,
          clearError: true,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _channelSubscription?.cancel();
    await _repository.close();
    await super.close();
  }
}
