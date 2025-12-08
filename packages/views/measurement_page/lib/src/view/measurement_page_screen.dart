import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n_service/l10n_service.dart';

import '../bloc/measurement_page_bloc.dart';

class MeasurementPageScreen extends StatelessWidget {
  const MeasurementPageScreen({super.key});

  static const String routeName = '/measurement';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MeasurementPageBloc(),
      child: const _MeasurementPageView(),
    );
  }
}

class _MeasurementPageView extends StatelessWidget {
  const _MeasurementPageView();

  @override
  Widget build(BuildContext context) {
    final gradient = _themeColors('measurement_page.background_gradient');

    return Scaffold(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

    children.add(_LobbyCard(state: state));

    children.addAll([
      const SizedBox(height: 28),
      _DeviceListCard(state: state),
      const SizedBox(height: 28),
      _TimelineCard(state: state),
    ]);

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
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.7);

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
                  context.read<MeasurementPageBloc>().add(
                    const MeasurementLobbyQrToggled(),
                  );
                },
                color: accent,
                icon: Icon(
                  state.showQr ? Icons.qr_code_scanner : Icons.qr_code_rounded,
                ),
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
                onPressed: state.lobbyActive
                    ? () {
                        context.read<MeasurementPageBloc>().add(
                          const MeasurementLobbyCodeRefreshed(),
                        );
                      }
                    : null,
                variant: SonalyzeButtonVariant.outlined,
                foregroundColor: accent,
                borderColor: accent.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(Icons.refresh),
                child: Text(_tr('measurement_page.lobby.actions.refresh')),
              ),
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
          if (state.showQr) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _themeColor(
                  'measurement_page.qr_background',
                ).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 120, color: accent),
                  const SizedBox(height: 12),
                  Text(
                    state.lobbyCode.isEmpty
                        ? _tr('measurement_page.qr_panel.placeholder')
                        : state.lobbyCode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr('measurement_page.qr_panel.helper'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
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
                device.name,
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<MeasurementDeviceRole>(
                value: device.role,
                isExpanded: true,
                isDense: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: onBackground.withValues(alpha: 0.6),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: onBackground.withValues(alpha: 0.85),
                ),
                dropdownColor: _themeColor('measurement_page.panel_background'),
                items: MeasurementDeviceRole.values.map((role) {
                  return DropdownMenuItem<MeasurementDeviceRole>(
                    value: role,
                    child: Text(_roleLabel(role)),
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
    final onPrimary = _themeColor('app.on_primary');

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
              SonalyzeButton(
                onPressed: state.steps.isEmpty
                    ? null
                    : () => context.read<MeasurementPageBloc>().add(
                        const MeasurementTimelineAdvanced(),
                      ),
                backgroundColor: activeColor,
                foregroundColor: onPrimary,
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(Icons.fast_forward_outlined),
                child: Text(_tr('measurement_page.timeline.advance')),
              ),
            ],
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
                Text(_tr(descriptor.titleKey), style: titleStyle),
                const SizedBox(height: 6),
                Text(_tr(descriptor.descriptionKey), style: descriptionStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(MeasurementDeviceRole role) {
  return _tr('measurement_page.roles.${role.name}');
}

String _tr(String keyPath) {
  final value = AppConstants.translation(keyPath);
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return '';
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  return AppConstants.getThemeColors(keyPath);
}
