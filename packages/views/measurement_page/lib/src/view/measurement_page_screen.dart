import 'package:backend_gateway/backend_gateway.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:room_modeling/room_modeling.dart';

import '../bloc/measurement_page_bloc.dart';

class MeasurementPageScreen extends StatelessWidget {
  const MeasurementPageScreen({super.key});

  static const String routeName = '/measurement';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MeasurementPageBloc(
            repository: GetIt.I<GatewayConnectionRepository>(),
            gatewayBloc: GetIt.I<GatewayConnectionBloc>(),
          ),
        ),
        BlocProvider(create: (_) => RoomModelingBloc()),
      ],
      child: const _MeasurementPageView(),
    );
  }
}

class _MeasurementPageView extends StatelessWidget {
  const _MeasurementPageView();

  @override
  Widget build(BuildContext context) {
    final gradient = _themeColors('measurement_page.background_gradient');

    return BlocListener<MeasurementPageBloc, MeasurementPageState>(
      listenWhen: (previous, current) =>
          previous.activeStepIndex != current.activeStepIndex,
      listener: (context, state) {
        final roomBloc = context.read<RoomModelingBloc>();
        if (state.activeStepIndex <= 1) {
          roomBloc.add(const StepChanged(RoomModelingStep.structure));
        } else if (state.activeStepIndex == 2) {
          roomBloc.add(const StepChanged(RoomModelingStep.furnishing));
        } else {
          roomBloc.add(const StepChanged(RoomModelingStep.audio));
        }
      },
      child: Scaffold(
        backgroundColor: _themeColor('app.background'),
        body: Container(
          decoration: BoxDecoration(
            gradient: gradient.length >= 2
                ? LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: gradient.isEmpty ? _themeColor('app.background') : null,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1280;
                final isMedium = constraints.maxWidth >= 960;
                final horizontalPadding = isWide
                    ? 96.0
                    : isMedium
                    ? 72.0
                    : 24.0;
                final verticalPadding = isWide ? 48.0 : 32.0;

                return ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: WidgetStateProperty.all<Color>(
                      _themeColor(
                        'measurement_page.scrollbar_thumb',
                      ).withValues(alpha: 0.75),
                    ),
                    thickness: const WidgetStatePropertyAll<double>(6),
                    radius: const Radius.circular(999),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _MeasurementHeader(),
                        SizedBox(height: isWide ? 40 : 32),
                        BlocBuilder<MeasurementPageBloc, MeasurementPageState>(
                          builder: (context, state) {
                            return _MeasurementPrimaryLayout(state: state);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasurementHeader extends StatelessWidget {
  const _MeasurementHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeBackground = _themeColor(
      'measurement_page.header_badge_background',
    );
    final badgeText = _themeColor('measurement_page.header_badge_text');
    final accentColor = _themeColor('measurement_page.accent');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: accentColor),
          tooltip: _tr('common.back'),
          style: IconButton.styleFrom(
            backgroundColor: accentColor.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: badgeBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _tr('measurement_page.badge'),
            style: textTheme.labelLarge?.copyWith(
              color: badgeText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _tr('measurement_page.title'),
          style: textTheme.displaySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _tr('measurement_page.subtitle'),
          style: textTheme.titleMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.78),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _MeasurementPrimaryLayout extends StatelessWidget {
  const _MeasurementPrimaryLayout({required this.state});

  final MeasurementPageState state;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    final hideRoomModelingTools = state.activeStepIndex >= 4;

    children.add(_LobbyCard(state: state));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        SizedBox(
          height: 600,
          child: RoomModelingWidget(
            bloc: context.read<RoomModelingBloc>(),
            hideToolsPanel: hideRoomModelingTools,
            readOnly: hideRoomModelingTools,
          ),
        ),
        const SizedBox(height: 28),
        _DeviceListCard(state: state),
        const SizedBox(height: 28),
        _TimelineCard(state: state),
      ],
    );

    if (state.lobbyActive && !state.isHost) {
      children.add(IgnorePointer(child: Opacity(opacity: 0.5, child: content)));
    } else {
      children.add(content);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({required this.state});

  final MeasurementPageState state;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('measurement_page.panel_background');
    final borderColor = _themeColor('measurement_page.panel_border');
    final accent = _themeColor('measurement_page.accent');
    final onPrimary = _themeColor('app.on_primary');

    Future<void> copyLink() async {
      if (state.inviteLink.isEmpty) {
        return;
      }
      context.read<MeasurementPageBloc>().add(
        const MeasurementLobbyLinkCopied(),
      );
      await Clipboard.setData(ClipboardData(text: state.inviteLink));
    }

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _tr('measurement_page.lobby.title'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _showQrCodeDialog(
                    context,
                    lobbyCode: state.lobbyCode,
                    accent: accent,
                    borderColor: borderColor,
                  );
                },
                color: accent,
                icon: const Icon(Icons.qr_code_rounded),
                tooltip: _tr('measurement_page.lobby.actions.toggle_qr'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _tr(state.lastActionMessage),
              key: ValueKey<String>(state.lastActionMessage),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!state.lobbyActive) ...[
                SonalyzeButton(
                  onPressed: () {
                    context.read<MeasurementPageBloc>().add(
                      const MeasurementLobbyCreated(),
                    );
                  },
                  backgroundColor: accent,
                  foregroundColor: onPrimary,
                  borderRadius: BorderRadius.circular(18),
                  icon: const Icon(Icons.play_circle_outline),
                  child: Text(_tr('measurement_page.lobby.actions.create')),
                ),
                SonalyzeButton(
                  onPressed: () => _showJoinLobbyDialog(
                    context,
                    context.read<MeasurementPageBloc>(),
                    accent,
                    borderColor,
                  ),
                  variant: SonalyzeButtonVariant.outlined,
                  foregroundColor: accent,
                  borderColor: accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  icon: const Icon(Icons.login),
                  child: Text(_tr('measurement_page.lobby.actions.join')),
                ),
              ] else if (state.isHost) ...[
                // Host controls could go here (e.g. close lobby)
              ],
              SonalyzeButton(
                onPressed: state.inviteLink.isEmpty ? null : copyLink,
                variant: SonalyzeButtonVariant.outlined,
                foregroundColor: accent,
                borderColor: accent.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(Icons.copy_all_outlined),
                child: Text(_tr('measurement_page.lobby.actions.copy')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LobbyField(
            label: _tr('measurement_page.lobby.code_label'),
            value: state.lobbyCode.isEmpty ? '— — — — — —' : state.lobbyCode,
            accent: accent,
          ),
          const SizedBox(height: 16),
          _LobbyField(
            label: _tr('measurement_page.lobby.link_label'),
            value: state.inviteLink.isEmpty
                ? _tr('measurement_page.lobby.link_placeholder')
                : state.inviteLink,
            accent: accent,
            isSelectable: true,
          ),
        ],
      ),
    );
  }
}

class _LobbyField extends StatelessWidget {
  const _LobbyField({
    required this.label,
    required this.value,
    required this.accent,
    this.isSelectable = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool isSelectable;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      fontWeight: FontWeight.w600,
    );
    final valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    final content = isSelectable
        ? SelectableText(value, style: valueStyle)
        : Text(value, style: valueStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: content,
        ),
      ],
    );
  }
}

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({required this.state});

  final MeasurementPageState state;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('measurement_page.panel_background');
    final borderColor = _themeColor('measurement_page.panel_border');
    final accent = _themeColor('measurement_page.accent');
    final waitColor = _themeColor('measurement_page.ready_badge_waiting');
    final readyColor = _themeColor('measurement_page.ready_badge_ready');
    final onPrimary = _themeColor('app.on_primary');

    final remoteDevices = state.devices
        .where((device) => !device.isLocal)
        .toList();
    final lastRemoteId = remoteDevices.isEmpty ? null : remoteDevices.last.id;

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr('measurement_page.devices.title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  SonalyzeButton(
                    onPressed: state.lobbyActive
                        ? () {
                            final alias =
                                'Remote kit ${remoteDevices.length + 1}';
                            context.read<MeasurementPageBloc>().add(
                              MeasurementDeviceDemoJoined(alias: alias),
                            );
                          }
                        : null,
                    backgroundColor: accent,
                    foregroundColor: onPrimary,
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(Icons.add_circle_outline),
                    child: Text(_tr('measurement_page.devices.demo_join')),
                  ),
                  SonalyzeButton(
                    onPressed: lastRemoteId == null
                        ? null
                        : () {
                            context.read<MeasurementPageBloc>().add(
                              MeasurementDeviceDemoLeft(deviceId: lastRemoteId),
                            );
                          },
                    variant: SonalyzeButtonVariant.outlined,
                    foregroundColor: accent,
                    borderColor: accent.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(Icons.remove_circle_outline),
                    child: Text(_tr('measurement_page.devices.demo_leave')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _tr('measurement_page.devices.helper'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          if (state.devices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: panelColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  _tr('measurement_page.devices.empty'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                _DeviceHeaderRow(accent: accent),
                const Divider(height: 24),
                for (final device in state.devices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _DeviceDataRow(
                      device: device,
                      readinessColor: device.isReady ? readyColor : waitColor,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeviceHeaderRow extends StatelessWidget {
  const _DeviceHeaderRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            _tr('measurement_page.devices.headers.device'),
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            _tr('measurement_page.devices.headers.role'),
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            _tr('measurement_page.devices.headers.latency'),
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            _tr('measurement_page.devices.headers.battery'),
            style: style,
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            _tr('measurement_page.devices.headers.ready'),
            style: style,
          ),
        ),
      ],
    );
  }
}

class _DeviceDataRow extends StatelessWidget {
  const _DeviceDataRow({required this.device, required this.readinessColor});

  final MeasurementDevice device;
  final Color readinessColor;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MeasurementPageBloc>();
    final textTheme = Theme.of(context).textTheme;
    final onBackground = Theme.of(context).colorScheme.onSurface;
    final accent = _themeColor('measurement_page.accent');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Icon(
                device.isLocal ? Icons.phone_iphone : Icons.podcasts,
                color: onBackground.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Text(
                _localizedOrRaw(device.name),
                style: textTheme.bodyLarge?.copyWith(
                  color: onBackground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (device.isLocal) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: readinessColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _tr('measurement_page.devices.local_badge'),
                    style: textTheme.labelSmall?.copyWith(
                      color: readinessColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MeasurementDeviceRole>(
                  value: device.role,
                  isExpanded: true,
                  isDense: false,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: onBackground.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: onBackground.withValues(alpha: 0.85),
                  ),
                  dropdownColor: _themeColor(
                    'measurement_page.panel_background',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: MeasurementDeviceRole.values.map((role) {
                    return DropdownMenuItem<MeasurementDeviceRole>(
                      value: role,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_roleLabel(role)),
                      ),
                    );
                  }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null) {
                      bloc.add(
                        MeasurementDeviceRoleChanged(
                          deviceId: device.id,
                          role: newRole,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${device.latencyMs} ms',
            style: textTheme.bodyMedium?.copyWith(
              color: onBackground.withValues(alpha: 0.75),
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${(device.batteryLevel * 100).clamp(0, 100).round()}%',
            style: textTheme.bodyMedium?.copyWith(
              color: onBackground.withValues(alpha: 0.75),
            ),
          ),
        ),
        SizedBox(
          width: 90,
          child: Switch.adaptive(
            value: device.isReady,
            onChanged: (_) =>
                bloc.add(MeasurementDeviceReadyToggled(device.id)),
            activeThumbColor: readinessColor,
          ),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.state});

  final MeasurementPageState state;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('measurement_page.panel_background');
    final activeColor = _themeColor('measurement_page.timeline_active');
    final inactiveColor = _themeColor('measurement_page.timeline_inactive');
    final backColor = _themeColor('measurement_page.timeline_back');
    final onPrimary = _themeColor('app.on_primary');

    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      builder: (context, roomState) {
        final atDeviceStep = state.activeStepIndex == 3;
        final hasSpeaker = roomState.furniture.any(
          (f) => f.type == FurnitureType.speaker,
        );
        final hasMic = roomState.furniture.any(
          (f) => f.type == FurnitureType.microphone,
        );
        final hasRequiredAudio = hasSpeaker && hasMic;
        final requiresClosedRoom = state.activeStepIndex <= 1;
        final canAdvance =
            state.steps.isNotEmpty &&
            state.activeStepIndex < state.steps.length - 1 &&
            (!requiresClosedRoom || roomState.isRoomClosed) &&
            (!atDeviceStep || hasRequiredAudio);

        return SonalyzeSurface(
          padding: const EdgeInsets.all(28),
          backgroundColor: panelColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('measurement_page.timeline.title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SonalyzeButton(
                        onPressed: state.activeStepIndex > 0
                            ? () => context.read<MeasurementPageBloc>().add(
                                const MeasurementTimelineStepBack(),
                              )
                            : null,
                        backgroundColor: backColor,
                        foregroundColor: onPrimary,
                        borderRadius: BorderRadius.circular(18),
                        icon: const Icon(Icons.fast_rewind_outlined),
                        child: Text(_tr('measurement_page.timeline.back')),
                      ),
                      const SizedBox(width: 12),
                      SonalyzeButton(
                        onPressed: canAdvance
                            ? () => context.read<MeasurementPageBloc>().add(
                                const MeasurementTimelineAdvanced(),
                              )
                            : null,
                        backgroundColor: activeColor,
                        foregroundColor: onPrimary,
                        borderRadius: BorderRadius.circular(18),
                        icon: const Icon(Icons.fast_forward_outlined),
                        child: Text(_tr('measurement_page.timeline.advance')),
                      ),
                    ],
                  ),
                ],
              ),
              if (atDeviceStep && !hasRequiredAudio)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _tr(
                      'measurement_page.timeline.place_devices_hint',
                      fallback:
                          'Place at least one speaker and one microphone to continue.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: inactiveColor),
                  ),
                ),
              if (requiresClosedRoom && !roomState.isRoomClosed)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _tr(
                      'measurement_page.timeline.close_room_hint',
                      fallback: 'Close the room outline before continuing.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: inactiveColor),
                  ),
                ),
              const SizedBox(height: 20),
              Column(
                children: [
                  for (var i = 0; i < state.steps.length; i++)
                    _TimelineStepTile(
                      descriptor: state.steps[i],
                      isActive: state.activeStepIndex == i,
                      isComplete: i < state.activeStepIndex,
                      isLast: i == state.steps.length - 1,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineStepTile extends StatelessWidget {
  const _TimelineStepTile({
    required this.descriptor,
    required this.isActive,
    required this.isComplete,
    required this.isLast,
    required this.activeColor,
    required this.inactiveColor,
  });

  final MeasurementStepDescriptor descriptor;
  final bool isActive;
  final bool isComplete;
  final bool isLast;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final descriptionStyle = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      height: 1.5,
    );

    final indicatorColor = isActive
        ? activeColor
        : isComplete
        ? activeColor.withValues(alpha: 0.5)
        : inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: indicatorColor.withValues(
                    alpha: isActive ? 0.25 : 0.18,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: indicatorColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${descriptor.index + 1}',
                    style: textTheme.labelLarge?.copyWith(
                      color: indicatorColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: indicatorColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(descriptor.titleKey, fallback: descriptor.fallbackTitle),
                  style: titleStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  _tr(
                    descriptor.descriptionKey,
                    fallback: descriptor.fallbackDescription,
                  ),
                  style: descriptionStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showQrCodeDialog(
  BuildContext context, {
  required String lobbyCode,
  required Color accent,
  required Color borderColor,
}) {
  final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _themeColor('measurement_page.qr_background'),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('measurement_page.qr_panel.title'),
                    style: Theme.of(dialogContext).textTheme.titleLarge
                        ?.copyWith(
                          color: Theme.of(dialogContext).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Icon(Icons.qr_code_2, size: 160, color: accent),
              const SizedBox(height: 20),
              Text(
                lobbyCode.isEmpty
                    ? _tr('measurement_page.qr_panel.placeholder')
                    : lobbyCode,
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(
                      color: Theme.of(dialogContext).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _tr('measurement_page.qr_panel.helper'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodyMedium?.copyWith(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _roleLabel(MeasurementDeviceRole role) {
  return _tr('measurement_page.roles.${role.name}');
}

String _tr(String keyPath, {String? fallback}) {
  final value = AppConstants.translation(keyPath);
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return keyPath;
}

String _localizedOrRaw(String keyOrText) {
  final value = _tr(keyOrText);
  return value.isNotEmpty ? value : keyOrText;
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  return AppConstants.getThemeColors(keyPath);
}

void _showJoinLobbyDialog(
  BuildContext context,
  MeasurementPageBloc bloc,
  Color accent,
  Color borderColor,
) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: _themeColor('measurement_page.panel_background'),
        title: Text(
          _tr('measurement_page.lobby.join_dialog.title'),
          style: TextStyle(color: accent),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: _tr('measurement_page.lobby.join_dialog.code_label'),
            labelStyle: TextStyle(color: accent),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_tr('common.cancel'), style: TextStyle(color: accent)),
          ),
          TextButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                bloc.add(MeasurementLobbyJoined(code: code));
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(_tr('common.join'), style: TextStyle(color: accent)),
          ),
        ],
      );
    },
  );
}
