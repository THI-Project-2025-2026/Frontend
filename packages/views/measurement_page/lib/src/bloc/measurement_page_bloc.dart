import 'dart:async';
import 'dart:math';
import 'package:backend_gateway/backend_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'measurement_page_event.dart';
part 'measurement_page_state.dart';

/// Bloc orchestrating collaborative measurement sessions.
///
/// Handles lobby creation, invite link / QR toggles, role selection, device
/// discovery, readiness toggles, and synthesises telemetry shown on the demo UI.
class MeasurementPageBloc
    extends Bloc<MeasurementPageEvent, MeasurementPageState> {
  MeasurementPageBloc({
    required GatewayConnectionRepository repository,
    required GatewayConnectionBloc gatewayBloc,
  }) : _repository = repository,
       _gatewayBloc = gatewayBloc,
       super(MeasurementPageState.initial()) {
    on<MeasurementLobbyCreated>(_onLobbyCreated);
    on<MeasurementLobbyJoined>(_onLobbyJoined);
    on<MeasurementLobbyRefreshed>(_onLobbyRefreshed);
    on<MeasurementLobbyQrToggled>(_onLobbyQrToggled);
    // on<MeasurementLobbyCodeRefreshed>(_onLobbyCodeRefreshed);
    on<MeasurementLobbyLinkCopied>(_onLobbyLinkCopied);
    on<MeasurementDeviceRoleChanged>(_onDeviceRoleChanged);
    on<MeasurementDeviceReadyToggled>(_onDeviceReadyToggled);
    on<MeasurementDeviceDemoJoined>(_onDeviceJoined);
    on<MeasurementDeviceDemoLeft>(_onDeviceLeft);
    on<MeasurementTimelineAdvanced>(_onTimelineAdvanced);
    on<MeasurementTimelineStepBack>(_onTimelineStepBack);

    _gatewaySubscription = _gatewayBloc.envelopes.listen((envelope) {
      if (envelope.isEvent && envelope.event == 'lobby.updated') {
        add(const MeasurementLobbyRefreshed());
      }
    });
  }

  final GatewayConnectionRepository _repository;
  final GatewayConnectionBloc _gatewayBloc;
  StreamSubscription? _gatewaySubscription;

  @override
  Future<void> close() {
    _gatewaySubscription?.cancel();
    return super.close();
  }

  Future<void> _onLobbyCreated(
    MeasurementLobbyCreated event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.create',
        'request_id': requestId,
        'data': <String, dynamic>{},
      });

      final response = await responseFuture;
      if (response.error != null) {
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String;
      final lobbyId = data['lobby_id'] as String;
      final adminDeviceId = data['admin_device_id'] as String;
      // We assume the creator is the current device, but we don't have our own device ID easily accessible here
      // unless we store it or get it from the gateway.
      // However, for 'create', we are definitely the host.

      emit(
        state.copyWith(
          lobbyCode: code,
          lobbyId: lobbyId,
          inviteLink: 'https://sonalyze.app/join/$code',
          lobbyActive: true,
          lastActionMessage: 'measurement_page.lobby.status_active',
          isHost: true,
          currentDeviceId: adminDeviceId, // In create, we are the admin
          activeStepIndex: max(state.activeStepIndex, 1),
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onLobbyJoined(
    MeasurementLobbyJoined event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.join',
        'request_id': requestId,
        'data': {'code': event.code},
      });

      final response = await responseFuture;
      if (response.error != null) {
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String;
      final lobbyId = data['lobby_id'] as String;
      // final adminDeviceId = data['admin_device_id'] as String;

      // We need to know OUR device ID to check if we are host.
      // The join response might not return OUR device ID explicitly if we don't look for it.
      // But wait, the gateway connection has a device_id.
      // For now, let's assume we are NOT host if we join (unless we rejoin our own lobby).
      // Actually, we should fetch the lobby details which includes participants.

      final participants = (data['participants'] as List)
          .cast<Map<String, dynamic>>();
      final devices = _mapParticipantsToDevices(participants);

      // To find out who WE are, we might need to ask the gateway 'identify' or check the response.
      // But for now, let's assume if we join, we are not the host initially unless the IDs match.
      // Since we don't have our ID easily, we'll rely on the fact that 'create' sets isHost=true.
      // If we join, we are likely not the host.
      // TODO: Get actual device ID from GatewayBloc or Repository.

      emit(
        state.copyWith(
          lobbyCode: code,
          lobbyId: lobbyId,
          inviteLink: 'https://sonalyze.app/join/$code',
          lobbyActive: true,
          lastActionMessage: 'measurement_page.lobby.status_active',
          devices: devices,
          isHost: false, // Assumption for now
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onLobbyRefreshed(
    MeasurementLobbyRefreshed event,
    Emitter<MeasurementPageState> emit,
  ) async {
    if (!state.lobbyActive || state.lobbyCode.isEmpty) return;

    final requestId = _generateRequestId();
    final responseFuture = _waitForResponse(requestId);

    try {
      await _repository.sendJson({
        'event': 'lobby.get',
        'request_id': requestId,
        'data': {'code': state.lobbyCode},
      });

      final response = await responseFuture;
      if (response.error != null) return;

      final data = response.data as Map<String, dynamic>;
      final lobbyId = data['lobby_id'] as String;
      final participants = (data['participants'] as List)
          .cast<Map<String, dynamic>>();
      final devices = _mapParticipantsToDevices(participants);

      emit(state.copyWith(devices: devices, lobbyId: lobbyId));
    } catch (e) {
      // Handle error
    }
  }

  List<MeasurementDevice> _mapParticipantsToDevices(
    List<Map<String, dynamic>> participants,
  ) {
    return participants.map((p) {
      final deviceId = p['device_id'] as String;
      final roleStr = p['role'] as String;
      final role = MeasurementDeviceRole.values.firstWhere(
        (e) => _mapRoleToBackend(e) == roleStr,
        orElse: () => MeasurementDeviceRole.none,
      );

      return MeasurementDevice(
        id: deviceId,
        name: 'Device ${deviceId.substring(0, 4)}', // Placeholder name
        role: role,
        isLocal: deviceId == state.currentDeviceId,
        isReady: false, // Not in backend model yet
        latencyMs: 0,
        batteryLevel: 1.0,
      );
    }).toList();
  }

  String _mapRoleToBackend(MeasurementDeviceRole role) {
    switch (role) {
      case MeasurementDeviceRole.microphone:
        return 'microphone';
      case MeasurementDeviceRole.loudspeaker:
        return 'speaker';
      case MeasurementDeviceRole.none:
        return 'none';
    }
  }

  void _onLobbyQrToggled(
    MeasurementLobbyQrToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(state.copyWith(showQr: !state.showQr));
  }

  void _onLobbyLinkCopied(
    MeasurementLobbyLinkCopied event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(
      state.copyWith(lastActionMessage: 'measurement_page.lobby.link_copied'),
    );
  }

  Future<void> _onDeviceRoleChanged(
    MeasurementDeviceRoleChanged event,
    Emitter<MeasurementPageState> emit,
  ) async {
    final devices = state.devices
        .map((device) {
          if (device.id == event.deviceId) {
            return device.copyWith(role: event.role);
          }
          return device;
        })
        .toList(growable: false);

    emit(state.copyWith(devices: devices));

    if (!state.lobbyActive || state.lobbyId.isEmpty) return;

    final requestId = _generateRequestId();
    try {
      await _repository.sendJson({
        'event': 'role.assign',
        'request_id': requestId,
        'data': {
          'lobby_id': state.lobbyId,
          'target_device_id': event.deviceId,
          'role': _mapRoleToBackend(event.role),
        },
      });
    } catch (e) {
      // Handle error
    }
  }

  void _onDeviceReadyToggled(
    MeasurementDeviceReadyToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    final devices = state.devices
        .map((device) {
          if (device.id == event.deviceId) {
            return device.copyWith(isReady: !device.isReady);
          }
          return device;
        })
        .toList(growable: false);

    emit(state.copyWith(devices: devices));
  }

  void _onDeviceJoined(
    MeasurementDeviceDemoJoined event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (!state.lobbyActive) {
      return;
    }
    final random = Random();
    final role = MeasurementDeviceRole
        .values[random.nextInt(MeasurementDeviceRole.values.length)];
    final device = MeasurementDevice(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: event.alias,
      role: role,
      isLocal: false,
      isReady: random.nextBool(),
      latencyMs: 14 + random.nextInt(26),
      batteryLevel: 0.6 + random.nextDouble() * 0.35,
    );
    final updated = List<MeasurementDevice>.from(state.devices)..add(device);
    emit(
      state.copyWith(
        devices: updated,
        lastActionMessage: 'measurement_page.lobby.device_joined',
      ),
    );
  }

  void _onDeviceLeft(
    MeasurementDeviceDemoLeft event,
    Emitter<MeasurementPageState> emit,
  ) {
    final updated = state.devices
        .where((device) => device.id != event.deviceId)
        .toList(growable: false);
    emit(
      state.copyWith(
        devices: updated,
        lastActionMessage: 'measurement_page.lobby.device_left',
      ),
    );
  }

  void _onTimelineAdvanced(
    MeasurementTimelineAdvanced event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (state.steps.isEmpty) {
      return;
    }
    final lastIndex = state.steps.length - 1;
    final nextIndex = min(state.activeStepIndex + 1, lastIndex);
    emit(state.copyWith(activeStepIndex: nextIndex));
  }

  void _onTimelineStepBack(
    MeasurementTimelineStepBack event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (state.steps.isEmpty) {
      return;
    }
    final prevIndex = max(state.activeStepIndex - 1, 0);
    emit(state.copyWith(activeStepIndex: prevIndex));
  }

  String _generateRequestId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<GatewayEnvelope> _waitForResponse(String requestId) {
    return _gatewayBloc.envelopes
        .firstWhere((e) => e.requestId == requestId)
        .timeout(const Duration(seconds: 10));
  }
}
