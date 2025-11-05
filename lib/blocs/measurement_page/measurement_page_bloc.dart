import 'dart:async';
import 'dart:math';
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
  MeasurementPageBloc() : super(MeasurementPageState.initial()) {
    on<MeasurementLobbyCreated>(_onLobbyCreated);
    on<MeasurementLobbyQrToggled>(_onLobbyQrToggled);
    on<MeasurementLobbyCodeRefreshed>(_onLobbyCodeRefreshed);
    on<MeasurementLobbyLinkCopied>(_onLobbyLinkCopied);
    on<MeasurementRoleSelected>(_onRoleSelected);
    on<MeasurementDeviceReadyToggled>(_onDeviceReadyToggled);
    on<MeasurementDeviceDemoJoined>(_onDeviceJoined);
    on<MeasurementDeviceDemoLeft>(_onDeviceLeft);
    on<MeasurementTelemetryTick>(_onTelemetryTick);
    on<MeasurementTimelineAdvanced>(_onTimelineAdvanced);
    on<MeasurementScanningToggled>(_onScanningToggled);

    _telemetryTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => add(const MeasurementTelemetryTick()),
    );
  }

  Timer? _telemetryTimer;

  @override
  Future<void> close() {
    _telemetryTimer?.cancel();
    return super.close();
  }

  void _onLobbyCreated(
    MeasurementLobbyCreated event,
    Emitter<MeasurementPageState> emit,
  ) {
    final code = _generateLobbyCode();
    emit(
      state.copyWith(
        lobbyCode: code,
        inviteLink: 'https://sonalyze.app/join/$code',
        lobbyActive: true,
        lastActionMessage: 'measurement_page.lobby.status_active',
      ),
    );
  }

  void _onLobbyQrToggled(
    MeasurementLobbyQrToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(state.copyWith(showQr: !state.showQr));
  }

  void _onLobbyCodeRefreshed(
    MeasurementLobbyCodeRefreshed event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (!state.lobbyActive) {
      return;
    }
    final code = _generateLobbyCode();
    emit(
      state.copyWith(
        lobbyCode: code,
        inviteLink: 'https://sonalyze.app/join/$code',
        lastActionMessage: 'measurement_page.lobby.code_refreshed',
      ),
    );
  }

  void _onLobbyLinkCopied(
    MeasurementLobbyLinkCopied event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(
      state.copyWith(lastActionMessage: 'measurement_page.lobby.link_copied'),
    );
  }

  void _onRoleSelected(
    MeasurementRoleSelected event,
    Emitter<MeasurementPageState> emit,
  ) {
    final devices = state.devices
        .map((device) {
          if (device.isLocal) {
            return device.copyWith(role: event.role);
          }
          return device;
        })
        .toList(growable: false);

    emit(
      state.copyWith(
        selectedRole: event.role,
        devices: devices,
        lastActionMessage: 'measurement_page.roles.updated',
      ),
    );
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

  void _onTelemetryTick(
    MeasurementTelemetryTick event,
    Emitter<MeasurementPageState> emit,
  ) {
    if (!state.lobbyActive) {
      return;
    }
    final random = Random();
    final devices = state.devices
        .map((device) {
          if (device.isLocal) {
            return device.copyWith(
              latencyMs: 8 + random.nextInt(7),
              batteryLevel: (device.batteryLevel - 0.002).clamp(0.35, 1.0),
            );
          }
          return device.copyWith(
            latencyMs: device.latencyMs + random.nextInt(7) - 3,
            batteryLevel: (device.batteryLevel - 0.0015).clamp(0.25, 1.0),
          );
        })
        .toList(growable: false);

    final uplink = (state.uplinkRssi + (random.nextDouble() * 2 - 1.0)).clamp(
      -60.0,
      -42.0,
    );
    final downlink = (state.downlinkRssi + (random.nextDouble() * 2 - 1.2))
        .clamp(-64.0, -45.0);
    final jitter = (state.networkJitterMs + random.nextInt(7) - 3)
        .clamp(2, 18)
        .toDouble();

    emit(
      state.copyWith(
        devices: devices,
        uplinkRssi: uplink,
        downlinkRssi: downlink,
        networkJitterMs: jitter,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  void _onTimelineAdvanced(
    MeasurementTimelineAdvanced event,
    Emitter<MeasurementPageState> emit,
  ) {
    final nextIndex = (state.activeStepIndex + 1) % state.steps.length;
    emit(state.copyWith(activeStepIndex: nextIndex));
  }

  void _onScanningToggled(
    MeasurementScanningToggled event,
    Emitter<MeasurementPageState> emit,
  ) {
    emit(state.copyWith(isScanning: !state.isScanning));
  }

  String _generateLobbyCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List<String>.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
