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
    on<MeasurementDeviceRoleChanged>(_onDeviceRoleChanged);
    on<MeasurementDeviceReadyToggled>(_onDeviceReadyToggled);
    on<MeasurementDeviceDemoJoined>(_onDeviceJoined);
    on<MeasurementDeviceDemoLeft>(_onDeviceLeft);
    on<MeasurementTimelineAdvanced>(_onTimelineAdvanced);
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

  void _onDeviceRoleChanged(
    MeasurementDeviceRoleChanged event,
    Emitter<MeasurementPageState> emit,
  ) {
    final devices = state.devices
        .map((device) {
          if (device.id == event.deviceId) {
            return device.copyWith(role: event.role);
          }
          return device;
        })
        .toList(growable: false);

    emit(state.copyWith(devices: devices));
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
    final nextIndex = (state.activeStepIndex + 1) % state.steps.length;
    emit(state.copyWith(activeStepIndex: nextIndex));
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
