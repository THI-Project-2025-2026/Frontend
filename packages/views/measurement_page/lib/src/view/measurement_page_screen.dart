import 'dart:async';

import 'package:backend_gateway/backend_gateway.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:recording_service/recording_service.dart';
import 'package:room_modeling/room_modeling.dart';
import 'package:uuid/uuid.dart';

import '../bloc/measurement_page_bloc.dart';

class MeasurementPageScreen extends StatelessWidget {
  const MeasurementPageScreen({super.key});

  static const String routeName = '/measurement';
  static const int _roleAssignmentStepIndex = 4;
  static const int _sweepStepIndex = 5;

  @override
  Widget build(BuildContext context) {
    final repository = GetIt.I<GatewayConnectionRepository>();
    final gatewayBloc = GetIt.I<GatewayConnectionBloc>();
    final gatewayConfig = GetIt.I<GatewayConfig>();
    // Create the HTTP client for backend requests through the gateway
    final httpClient = BackendHttpClient(config: gatewayConfig);
    // Use the actual device ID from gateway config - this is the same ID
    // the backend uses to identify this device
    final localDeviceId = gatewayConfig.deviceId;
    // Materials repository for acoustic material selection
    final materialsRepository = SimulationMaterialsRepository(
      httpClient: httpClient,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MeasurementPageBloc(
            repository: repository,
            gatewayBloc: gatewayBloc,
            httpClient: httpClient,
            localDeviceId: localDeviceId,
          ),
        ),
        BlocProvider(create: (_) => RoomModelingBloc()),
      ],
      child: _MeasurementPageView(materialsRepository: materialsRepository),
    );
  }
}

final _roomSnapshotSender = _RoomSnapshotSender();
final _roomSnapshotApplier = _RoomSnapshotApplier();

class _AudioRoleSlot {
  const _AudioRoleSlot({
    required this.id,
    required this.label,
    required this.role,
    required this.furnitureId,
    required this.color,
  });

  final String id;
  final String label;
  final MeasurementDeviceRole role;
  final String furnitureId;
  final Color color;
}

class _RoleColorDot extends StatelessWidget {
  const _RoleColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

const double _roleColumnMinWidth = 220;
const double _roleColumnMaxWidth = 420;

class _RoleColumn extends StatelessWidget {
  const _RoleColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      fit: FlexFit.loose,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : _roleColumnMaxWidth;
          double maxWidth = availableWidth;
          if (maxWidth > _roleColumnMaxWidth) {
            maxWidth = _roleColumnMaxWidth;
          }
          double minWidth = maxWidth;
          if (minWidth > _roleColumnMinWidth) {
            minWidth = _roleColumnMinWidth;
          }
          return ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          );
        },
      ),
    );
  }
}

List<_AudioRoleSlot> _buildAudioRoleSlots(RoomModelingState roomState) {
  final slots = <_AudioRoleSlot>[];
  var speakerIndex = 1;
  var microphoneIndex = 1;

  for (final furniture in roomState.furniture) {
    if (furniture.type == FurnitureType.speaker) {
      slots.add(
        _AudioRoleSlot(
          id: 'speaker-$speakerIndex',
          label:
              '${_baseRoleLabel(MeasurementDeviceRole.loudspeaker)} $speakerIndex',
          role: MeasurementDeviceRole.loudspeaker,
          furnitureId: furniture.id,
          color: _roleColorFor(
            MeasurementDeviceRole.loudspeaker,
            speakerIndex - 1,
          ),
        ),
      );
      speakerIndex++;
    } else if (furniture.type == FurnitureType.microphone) {
      slots.add(
        _AudioRoleSlot(
          id: 'microphone-$microphoneIndex',
          label:
              '${_baseRoleLabel(MeasurementDeviceRole.microphone)} $microphoneIndex',
          role: MeasurementDeviceRole.microphone,
          furnitureId: furniture.id,
          color: _roleColorFor(
            MeasurementDeviceRole.microphone,
            microphoneIndex - 1,
          ),
        ),
      );
      microphoneIndex++;
    }
  }

  return slots;
}

bool _roleAssignmentsComplete(
  List<MeasurementDevice> devices,
  List<_AudioRoleSlot> slots,
) {
  if (slots.isEmpty) {
    return false;
  }

  final assigned = <String>{};
  for (final device in devices) {
    final slotId = device.roleSlotId;
    if (slotId == null) continue;
    assigned.add(slotId);
  }

  if (assigned.length != slots.length) {
    return false;
  }

  return slots.every((slot) => assigned.contains(slot.id));
}

Set<String> _assignedSlotIds(
  List<MeasurementDevice> devices,
  String currentId,
) {
  final result = <String>{};
  for (final device in devices) {
    if (device.id == currentId) continue;
    final slotId = device.roleSlotId;
    if (slotId != null) {
      result.add(slotId);
    }
  }
  return result;
}

_AudioRoleSlot? _slotForId(String? id, List<_AudioRoleSlot> slots) {
  if (id == null) return null;
  for (final slot in slots) {
    if (slot.id == id) return slot;
  }
  return null;
}

Color _roleColorFor(MeasurementDeviceRole role, int index) {
  final palette = role == MeasurementDeviceRole.loudspeaker
      ? _speakerColors
      : _microphoneColors;
  return palette[index % palette.length];
}

String _baseRoleLabel(MeasurementDeviceRole role) {
  switch (role) {
    case MeasurementDeviceRole.loudspeaker:
      return _tr(
        'measurement_page.roles.loudspeaker_label',
        fallback: 'Speaker',
      );
    case MeasurementDeviceRole.microphone:
      return _tr(
        'measurement_page.roles.microphone_label',
        fallback: 'Microphone',
      );
    case MeasurementDeviceRole.none:
      return _tr('measurement_page.roles.none', fallback: 'None');
  }
}

void _syncRoleHighlights(
  BuildContext context,
  MeasurementPageState measurementState,
  RoomModelingState roomState,
) {
  final slots = _buildAudioRoleSlots(roomState);
  final lookup = {for (final slot in slots) slot.id: slot};
  final highlights = <String, Color>{};

  for (final device in measurementState.devices) {
    final slotId = device.roleSlotId;
    if (slotId == null) continue;
    final slot = lookup[slotId];
    if (slot == null) continue;
    highlights[slot.furnitureId] = slot.color;
  }

  final roomBloc = context.read<RoomModelingBloc>();
  if (!mapEquals(roomBloc.state.deviceHighlights, highlights)) {
    roomBloc.add(DeviceHighlightsUpdated(highlights));
  }
}

const List<Color> _speakerColors = [
  Color(0xFF6C8EF5),
  Color(0xFF4EC4B0),
  Color(0xFFEF6C9D),
  Color(0xFF8B7FFB),
  Color(0xFF3CBCC3),
  Color(0xFFF6B76C),
];

const List<Color> _microphoneColors = [
  Color(0xFFF59E0B),
  Color(0xFF36B37E),
  Color(0xFF3AA0F3),
  Color(0xFFD97757),
  Color(0xFF7C73E6),
  Color(0xFFF470A7),
];

class _MeasurementPageView extends StatefulWidget {
  const _MeasurementPageView({required this.materialsRepository});

  final SimulationMaterialsRepository materialsRepository;

  @override
  State<_MeasurementPageView> createState() => _MeasurementPageViewState();
}

class _MeasurementPageViewState extends State<_MeasurementPageView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _analysisResultsKey = GlobalKey();
  AnalysisResults? _previousAnalysisResults;

  @override
  void initState() {
    super.initState();
    debugPrint('[NAV_DEBUG] _MeasurementPageViewState.initState called');
    // Request all necessary permissions when the page opens
    _requestPermissions();
    // Load acoustic materials
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final roomBloc = context.read<RoomModelingBloc>();
    roomBloc.add(const LoadMaterials());
    try {
      final materials = await widget.materialsRepository.fetchMaterials();
      final acousticMaterials = materials
          .map(
            (m) => AcousticMaterial(
              id: m.id,
              displayName: m.displayName,
              absorption: m.absorption,
              scattering: m.scattering,
            ),
          )
          .toList();
      roomBloc.add(MaterialsLoaded(acousticMaterials));
    } catch (e) {
      roomBloc.add(MaterialsLoadFailed(e.toString()));
    }
  }

  @override
  void dispose() {
    debugPrint(
      '[NAV_DEBUG] _MeasurementPageViewState.dispose called - PAGE IS BEING DISPOSED',
    );
    debugPrint('[NAV_DEBUG] Stack trace: ${StackTrace.current}');
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAnalysisResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _analysisResultsKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          alignment: 0.1, // Slight offset from top
        );
      }
    });
  }

  Future<void> _requestPermissions() async {
    final log = MeasurementDebugLogger.instance;
    log.info('MeasurementPage', 'Requesting permissions on page open');

    try {
      final recordingService = createRecordingService();
      final hasPermission = await recordingService.hasPermission();

      if (!hasPermission) {
        log.info(
          'MeasurementPage',
          'Microphone permission not granted, requesting...',
        );
        await recordingService.requestPermission();
        final granted = await recordingService.hasPermission();
        if (granted) {
          log.info('MeasurementPage', 'Microphone permission granted');
        } else {
          log.warning('MeasurementPage', 'Microphone permission denied');
        }
      } else {
        log.info('MeasurementPage', 'Microphone permission already granted');
      }
    } catch (e, stackTrace) {
      log.error(
        'MeasurementPage',
        'Error requesting permissions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _themeColors('measurement_page.background_gradient');

    return MultiBlocListener(
      listeners: [
        BlocListener<MeasurementPageBloc, MeasurementPageState>(
          listenWhen: (previous, current) {
            final changed = previous.activeStepIndex != current.activeStepIndex;
            if (changed) {
              debugPrint(
                '[NAV_DEBUG] activeStepIndex changed: ${previous.activeStepIndex} -> ${current.activeStepIndex}',
              );
            }
            return changed;
          },
          listener: (context, state) {
            debugPrint(
              '[NAV_DEBUG] activeStepIndex listener fired, step=${state.activeStepIndex}',
            );
            final roomBloc = context.read<RoomModelingBloc>();
            if (state.activeStepIndex <= 1) {
              roomBloc.add(const StepChanged(RoomModelingStep.structure));
            } else if (state.activeStepIndex == 2) {
              roomBloc.add(const StepChanged(RoomModelingStep.furnishing));
            } else {
              roomBloc.add(const StepChanged(RoomModelingStep.audio));
            }
            if (state.activeStepIndex ==
                MeasurementPageScreen._roleAssignmentStepIndex) {
              unawaited(_roomSnapshotSender.maybeSend(context, state));
            }
          },
        ),
        BlocListener<MeasurementPageBloc, MeasurementPageState>(
          listenWhen: (previous, current) =>
              previous.devices != current.devices,
          listener: (context, state) {
            _syncRoleHighlights(
              context,
              state,
              context.read<RoomModelingBloc>().state,
            );
          },
        ),
        BlocListener<MeasurementPageBloc, MeasurementPageState>(
          listenWhen: (previous, current) =>
              previous.sharedRoomPlanVersion != current.sharedRoomPlanVersion &&
              current.sharedRoomPlan != null,
          listener: (context, state) {
            if (state.isHost) {
              return;
            }
            final plan = state.sharedRoomPlan;
            if (plan == null) {
              return;
            }
            _roomSnapshotApplier.apply(context.read<RoomModelingBloc>(), plan);
          },
        ),
        BlocListener<RoomModelingBloc, RoomModelingState>(
          listenWhen: (previous, current) =>
              previous.furniture != current.furniture,
          listener: (context, state) {
            _syncRoleHighlights(
              context,
              context.read<MeasurementPageBloc>().state,
              state,
            );
          },
        ),
        BlocListener<MeasurementPageBloc, MeasurementPageState>(
          listenWhen: (previous, current) {
            final changed =
                previous.activeStepIndex != current.activeStepIndex &&
                current.activeStepIndex ==
                    MeasurementPageScreen._sweepStepIndex;
            if (changed) {
              debugPrint(
                '[NAV_DEBUG] Sweep step listener will fire - entering step 5',
              );
            }
            return changed;
          },
          listener: (context, state) {
            debugPrint(
              '[NAV_DEBUG] Sweep step listener fired, sweepStatus=${state.sweepStatus}',
            );
            if (state.sweepStatus == SweepStatus.idle) {
              debugPrint('[NAV_DEBUG] Starting sweep request');
              context.read<MeasurementPageBloc>().add(
                const MeasurementSweepStartRequested(),
              );
            }
            debugPrint('[NAV_DEBUG] Showing sweep progress dialog');
            _showSweepProgressDialog(context);
          },
        ),
      ],
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
                    controller: _scrollController,
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
                            // Scroll to analysis results when they first appear
                            if (state.analysisResults != null &&
                                _previousAnalysisResults == null) {
                              _scrollToAnalysisResults();
                            }
                            _previousAnalysisResults = state.analysisResults;
                            return _MeasurementPrimaryLayout(
                              state: state,
                              analysisResultsKey: _analysisResultsKey,
                            );
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
  const _MeasurementPrimaryLayout({
    required this.state,
    required this.analysisResultsKey,
  });

  final MeasurementPageState state;
  final GlobalKey analysisResultsKey;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    final isGuestViewer = state.lobbyActive && !state.isHost;
    final hideRoomModelingTools =
        state.activeStepIndex >=
            MeasurementPageScreen._roleAssignmentStepIndex ||
        isGuestViewer;

    children.add(_LobbyCard(state: state));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        BlocBuilder<RoomModelingBloc, RoomModelingState>(
          builder: (context, roomState) {
            return _DeviceListCard(state: state, roomState: roomState);
          },
        ),
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
        _TimelineCard(state: state),
        // Show results panel below timeline when analysis results are available
        if (state.analysisResults != null) ...[
          const SizedBox(height: 28),
          _AnalysisResultsCard(
            key: analysisResultsKey,
            results: state.analysisResults!,
          ),
        ],
      ],
    );

    if (isGuestViewer) {
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
  const _DeviceListCard({required this.state, required this.roomState});

  final MeasurementPageState state;
  final RoomModelingState roomState;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('measurement_page.panel_background');
    final borderColor = _themeColor('measurement_page.panel_border');
    final accent = _themeColor('measurement_page.accent');
    final slots = _buildAudioRoleSlots(roomState);
    final canEditRoles =
        state.activeStepIndex == MeasurementPageScreen._roleAssignmentStepIndex;

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('measurement_page.devices.title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
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
                      slots: slots,
                      takenSlots: _assignedSlotIds(state.devices, device.id),
                      canEditRoles: canEditRoles,
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
        _RoleColumn(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              _tr('measurement_page.devices.headers.role'),
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceDataRow extends StatelessWidget {
  const _DeviceDataRow({
    required this.device,
    required this.slots,
    required this.takenSlots,
    required this.canEditRoles,
  });

  final MeasurementDevice device;
  final List<_AudioRoleSlot> slots;
  final Set<String> takenSlots;
  final bool canEditRoles;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MeasurementPageBloc>();
    final textTheme = Theme.of(context).textTheme;
    final onBackground = Theme.of(context).colorScheme.onSurface;
    final accent = _themeColor('measurement_page.accent');
    final selectedSlot = _slotForId(device.roleSlotId, slots);
    final availableSlots = slots
        .where(
          (slot) =>
              slot.id == device.roleSlotId || !takenSlots.contains(slot.id),
        )
        .toList(growable: false);
    final dropdownChoices = <_AudioRoleSlot?>[null, ...availableSlots];

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
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _tr('measurement_page.devices.local_badge'),
                    style: textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _RoleColumn(
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
                child: DropdownButton<_AudioRoleSlot?>(
                  value: dropdownChoices.contains(selectedSlot)
                      ? selectedSlot
                      : null,
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
                  items: dropdownChoices
                      .map(
                        (slot) => DropdownMenuItem<_AudioRoleSlot?>(
                          value: slot,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: slot == null
                                ? Text(_roleLabel(MeasurementDeviceRole.none))
                                : Row(
                                    children: [
                                      _RoleColorDot(color: slot.color),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(slot.label)),
                                    ],
                                  ),
                          ),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) {
                    return dropdownChoices.map((slot) {
                      if (slot == null) {
                        final customLabel =
                            device.role != MeasurementDeviceRole.none
                            ? device.roleLabel
                            : null;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            customLabel?.isNotEmpty == true
                                ? customLabel!
                                : _roleLabel(MeasurementDeviceRole.none),
                          ),
                        );
                      }
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            _RoleColorDot(color: slot.color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(slot.label)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  onChanged: canEditRoles
                      ? (newSlot) {
                          bloc.add(
                            MeasurementDeviceRoleChanged(
                              deviceId: device.id,
                              role: newSlot?.role ?? MeasurementDeviceRole.none,
                              roleSlotId: newSlot?.id,
                              roleLabel: newSlot?.label,
                              roleColor: newSlot?.color,
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Maps backend icon identifiers to Flutter Icons.
IconData _mapIconName(String? iconName) {
  return switch (iconName) {
    'timer' => Icons.timer_outlined,
    'speed' => Icons.speed_outlined,
    'record_voice_over' => Icons.record_voice_over_outlined,
    'hearing' => Icons.hearing_outlined,
    'music_note' => Icons.music_note_outlined,
    'graphic_eq' => Icons.graphic_eq_outlined,
    'surround_sound' => Icons.surround_sound_outlined,
    'signal_cellular_alt' => Icons.signal_cellular_alt_outlined,
    _ => Icons.analytics_outlined,
  };
}

/// Card displaying full analysis results on step 7 (Review impulse results).
///
/// Uses a universal format - renders whatever metrics the backend provides.
class _AnalysisResultsCard extends StatelessWidget {
  const _AnalysisResultsCard({super.key, required this.results});

  final AnalysisResults results;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('measurement_page.panel_background');
    final accent = _themeColor('measurement_page.accent');

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _tr(
                    'measurement_page.results.title',
                    fallback: 'Impulse Response Analysis',
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _tr(
              'measurement_page.results.subtitle',
              fallback:
                  'Acoustic metrics calculated from the measured impulse response.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // Render metrics dynamically from universal format
          if (results.metrics.isNotEmpty)
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                for (final metric in results.metrics)
                  _ResultMetricTile(
                    label: metric.label,
                    value: metric.formattedValue,
                    unit: metric.unit ?? '',
                    description: metric.description ?? '',
                    icon: _mapIconName(metric.icon),
                  ),
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _tr(
                    'measurement_page.results.no_metrics',
                    fallback: 'No metrics available',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Individual metric tile for the results card.
class _ResultMetricTile extends StatelessWidget {
  const _ResultMetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.description,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = _themeColor('measurement_page.accent');

    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Dropdown selector for measurement profile (frequency range).
class _MeasurementProfileSelector extends StatelessWidget {
  const _MeasurementProfileSelector({
    required this.selectedProfile,
    required this.enabled,
  });

  final MeasurementProfile selectedProfile;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = _themeColor('measurement_page.accent');
    final onBackground = Theme.of(context).colorScheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          Icons.tune_outlined,
          size: 20,
          color: accent.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Text(
          _tr(
            'measurement_page.profile.label',
            fallback: 'Measurement Profile',
          ),
          style: textTheme.labelLarge?.copyWith(
            color: onBackground.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MeasurementProfile>(
              value: selectedProfile,
              isDense: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: onBackground.withValues(alpha: 0.6),
                size: 20,
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: onBackground.withValues(alpha: 0.85),
              ),
              dropdownColor: _themeColor('measurement_page.panel_background'),
              borderRadius: BorderRadius.circular(12),
              items: MeasurementProfile.values.map((profile) {
                return DropdownMenuItem<MeasurementProfile>(
                  value: profile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tr(
                            profile.labelKey,
                            fallback: profile.fallbackLabel,
                          ),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${profile.sweepFStart.toInt()} Hz - ${profile.sweepFEnd.toInt()} Hz',
                          style: textTheme.bodySmall?.copyWith(
                            color: onBackground.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              selectedItemBuilder: (context) {
                return MeasurementProfile.values.map((profile) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _tr(profile.labelKey, fallback: profile.fallbackLabel),
                    ),
                  );
                }).toList();
              },
              onChanged: enabled
                  ? (profile) {
                      if (profile != null) {
                        context.read<MeasurementPageBloc>().add(
                          MeasurementProfileChanged(profile: profile),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _tr(
              selectedProfile.descriptionKey,
              fallback: selectedProfile.fallbackDescription,
            ),
            style: textTheme.bodySmall?.copyWith(
              color: onBackground.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
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
        final atRoleStep =
            state.activeStepIndex ==
            MeasurementPageScreen._roleAssignmentStepIndex;
        final atSweepStep =
            state.activeStepIndex == MeasurementPageScreen._sweepStepIndex;
        final hasSpeaker = roomState.furniture.any(
          (f) => f.type == FurnitureType.speaker,
        );
        final hasMic = roomState.furniture.any(
          (f) => f.type == FurnitureType.microphone,
        );
        final roleSlots = _buildAudioRoleSlots(roomState);
        final rolesComplete = _roleAssignmentsComplete(
          state.devices,
          roleSlots,
        );
        final hasRequiredAudio = hasSpeaker && hasMic;
        final requiresClosedRoom = state.activeStepIndex <= 1;
        final sweepInProgress =
            state.sweepStatus == SweepStatus.creatingJob ||
            state.sweepStatus == SweepStatus.creatingSession ||
            state.sweepStatus == SweepStatus.running;
        final canAdvance =
            state.steps.isNotEmpty &&
            state.activeStepIndex < state.steps.length - 1 &&
            (!requiresClosedRoom || roomState.isRoomClosed) &&
            (!atDeviceStep || hasRequiredAudio) &&
            (!atRoleStep || rolesComplete) &&
            (!atSweepStep || state.sweepStatus == SweepStatus.completed);

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
                        onPressed: state.activeStepIndex > 0 && !sweepInProgress
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
                        onPressed: canAdvance && !sweepInProgress
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
              const SizedBox(height: 16),
              _MeasurementProfileSelector(
                selectedProfile: state.measurementProfile,
                enabled: !sweepInProgress,
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
              if (atRoleStep && !rolesComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _tr(
                      'measurement_page.timeline.assign_roles_hint',
                      fallback:
                          'Assign every speaker and microphone slot to a connected device.',
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
  return _tr(
    'measurement_page.roles.${role.name}',
    fallback: _baseRoleLabel(role),
  );
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
  if (keyOrText.contains('.')) {
    final value = _tr(keyOrText);
    return value.isNotEmpty ? value : keyOrText;
  }
  return keyOrText;
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

class _RoomSnapshotSender {
  _RoomSnapshotSender()
    : _repository = GetIt.I<GatewayConnectionRepository>(),
      _exporter = RoomPlanExporter(),
      _uuid = const Uuid();

  final GatewayConnectionRepository _repository;
  final RoomPlanExporter _exporter;
  final Uuid _uuid;

  Future<void> maybeSend(
    BuildContext context,
    MeasurementPageState state,
  ) async {
    if (!state.isHost || !state.lobbyActive || state.lobbyId.isEmpty) {
      return;
    }
    final roomBloc = context.read<RoomModelingBloc>();
    final snapshot = _exporter.export(roomBloc.state);
    final payload = {
      'event': 'lobby.room_snapshot',
      'request_id': _uuid.v4(),
      'data': {'lobby_id': state.lobbyId, 'room': snapshot},
    };
    try {
      await _repository.sendJson(payload);
    } catch (error, stackTrace) {
      debugPrint('Room snapshot sync failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }
}

class _RoomSnapshotApplier {
  _RoomSnapshotApplier() : _importer = RoomPlanImporter();

  final RoomPlanImporter _importer;

  void apply(RoomModelingBloc bloc, Map<String, dynamic> plan) {
    final result = _importer.tryImport(plan);
    if (result == null) {
      return;
    }
    bloc.add(RoomPlanImported(result));
  }
}

void _showSweepProgressDialog(BuildContext context) {
  debugPrint('[NAV_DEBUG] _showSweepProgressDialog called');
  // Clear previous logs when starting a new sweep
  MeasurementDebugLogger.instance.clear();
  MeasurementDebugLogger.instance.info(
    'SweepDialog',
    'Starting new measurement sweep',
  );

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      debugPrint('[NAV_DEBUG] showDialog builder called');
      return BlocProvider.value(
        value: context.read<MeasurementPageBloc>(),
        child: _SweepProgressDialog(dialogContext: dialogContext),
      );
    },
  ).then((_) {
    debugPrint('[NAV_DEBUG] showDialog.then() called - dialog was closed');
  });
}

class _SweepProgressDialog extends StatefulWidget {
  const _SweepProgressDialog({required this.dialogContext});

  final BuildContext dialogContext;

  @override
  State<_SweepProgressDialog> createState() => _SweepProgressDialogState();
}

class _SweepProgressDialogState extends State<_SweepProgressDialog> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _showDebugLog = false;
  bool _hasPopped = false; // Prevent multiple Navigator.pop() calls
  final ScrollController _logScrollController = ScrollController();
  List<MeasurementLogEntry> _logEntries = [];
  StreamSubscription<MeasurementLogEntry>? _logSubscription;

  // Total duration of the audio file (approx 15s based on backend)
  static const int _totalDurationSeconds = 15;

  @override
  void initState() {
    super.initState();
    debugPrint('[NAV_DEBUG] _SweepProgressDialogState.initState');
    _logEntries = List.from(MeasurementDebugLogger.instance.entries);
    _logSubscription = MeasurementDebugLogger.instance.stream.listen((entry) {
      if (mounted) {
        setState(() {
          _logEntries = List.from(MeasurementDebugLogger.instance.entries);
        });
        // Auto-scroll to bottom when new log arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    debugPrint(
      '[NAV_DEBUG] _SweepProgressDialogState.dispose - DIALOG BEING DISPOSED',
    );
    _timer?.cancel();
    _logSubscription?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsElapsed < _totalDurationSeconds) {
          _secondsElapsed++;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _copyLogs() async {
    final logs = MeasurementDebugLogger.instance.exportLogs();
    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'measurement_page.sweep.logs_copied',
              fallback: 'Debug logs copied to clipboard',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MeasurementPageBloc, MeasurementPageState>(
      listener: (context, state) {
        debugPrint(
          '[NAV_DEBUG] Dialog BlocConsumer listener: sweepStatus=${state.sweepStatus}, playbackPhase=${state.playbackPhase}',
        );
        MeasurementDebugLogger.instance.debug(
          'SweepDialog',
          'State changed',
          data: {
            'sweepStatus': state.sweepStatus.toString(),
            'playbackPhase': state.playbackPhase.toString(),
          },
        );

        if (state.sweepStatus == SweepStatus.running &&
            state.playbackPhase == PlaybackPhase.measurementPlaying) {
          _startTimer();
        }
        if (state.sweepStatus == SweepStatus.completed) {
          debugPrint(
            '[NAV_DEBUG] SweepStatus.completed detected in dialog listener',
          );
          _timer?.cancel();
          MeasurementDebugLogger.instance.info(
            'SweepDialog',
            'Measurement completed successfully',
          );
          // Close dialog on next frame to avoid any race conditions
          // Use the dialog's context to ensure we only pop the dialog, not the page
          // IMPORTANT: Check _hasPopped to prevent multiple pops (the listener fires multiple times)
          if (!_hasPopped) {
            _hasPopped = true;
            debugPrint(
              '[NAV_DEBUG] Scheduling dialog pop on next frame (first time only)',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              debugPrint(
                '[NAV_DEBUG] PostFrameCallback executing, mounted=$mounted',
              );
              final canPop = Navigator.of(widget.dialogContext).canPop();
              debugPrint('[NAV_DEBUG] Navigator.canPop()=$canPop');
              if (mounted && canPop) {
                debugPrint('[NAV_DEBUG] Calling Navigator.pop() for dialog');
                Navigator.of(widget.dialogContext).pop();
                debugPrint('[NAV_DEBUG] Navigator.pop() completed');
              }
            });
          } else {
            debugPrint(
              '[NAV_DEBUG] SweepStatus.completed but _hasPopped=true, skipping pop',
            );
          }
        }
        if (state.sweepStatus == SweepStatus.failed) {
          debugPrint(
            '[NAV_DEBUG] SweepStatus.failed detected in dialog listener',
          );
          _timer?.cancel();
          MeasurementDebugLogger.instance.error(
            'SweepDialog',
            'Measurement failed',
            data: {'error': state.sweepError},
          );
        }
      },
      builder: (context, state) {
        final isCreatingJob =
            state.sweepStatus == SweepStatus.creatingJob ||
            state.sweepStatus == SweepStatus.creatingSession ||
            state.sweepStatus == SweepStatus.running ||
            state.sweepStatus == SweepStatus.requestingAnalysis ||
            state.sweepStatus == SweepStatus.completed;

        final isReceived =
            state.sweepStatus == SweepStatus.creatingSession ||
            state.sweepStatus == SweepStatus.running ||
            state.sweepStatus == SweepStatus.requestingAnalysis ||
            state.sweepStatus == SweepStatus.completed;

        final isVerified =
            state.sweepStatus == SweepStatus.running ||
            state.sweepStatus == SweepStatus.requestingAnalysis ||
            state.sweepStatus == SweepStatus.completed;

        final isRecordingDone =
            state.sweepStatus == SweepStatus.requestingAnalysis ||
            state.sweepStatus == SweepStatus.completed;

        final isAnalyzing = state.sweepStatus == SweepStatus.requestingAnalysis;

        final isCompleted = state.sweepStatus == SweepStatus.completed;
        final isFailed = state.sweepStatus == SweepStatus.failed;
        final isPlayingMeasurement =
            state.playbackPhase == PlaybackPhase.measurementPlaying &&
            state.sweepStatus == SweepStatus.running;

        return Dialog(
          backgroundColor: _themeColor('measurement_page.panel_background'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _showDebugLog ? 800 : 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and debug toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _tr(
                              'measurement_page.sweep.dialog_title',
                              fallback: 'Measurement in Progress',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _copyLogs,
                              icon: const Icon(Icons.copy),
                              tooltip: _tr(
                                'measurement_page.sweep.copy_logs',
                                fallback: 'Copy debug logs',
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _showDebugLog = !_showDebugLog;
                                });
                              },
                              icon: Icon(
                                _showDebugLog
                                    ? Icons.bug_report
                                    : Icons.bug_report_outlined,
                              ),
                              tooltip: _tr(
                                'measurement_page.sweep.toggle_debug',
                                fallback: 'Toggle debug log',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Progress steps
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.1', fallback: 'Step 1: Initiating measurement'),
                      isCompleted: isCreatingJob,
                      isActive: state.sweepStatus == SweepStatus.creatingJob,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.2_3', fallback: 'Step 2-3: Server notification & ready signals'),
                      isCompleted: isReceived,
                      isActive:
                          state.sweepStatus == SweepStatus.creatingSession,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.4_6', fallback: 'Step 4-6: Audio download & verification'),
                      isCompleted: isVerified,
                      isActive: false,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.7_8', fallback: 'Step 7-8: Starting recording'),
                      isCompleted: isPlayingMeasurement || isRecordingDone,
                      isActive:
                          isVerified &&
                          !isPlayingMeasurement &&
                          !isRecordingDone &&
                          !isFailed,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.9', fallback: 'Step 9: Playing audiofile'),
                      isCompleted: isRecordingDone,
                      isActive: isPlayingMeasurement,
                      trailing: isPlayingMeasurement || isRecordingDone
                          ? Text(
                              '${_secondsElapsed}s / ${_totalDurationSeconds}s',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            )
                          : null,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.10_11', fallback: 'Step 10-11: Uploading recordings'),
                      isCompleted: isRecordingDone,
                      isActive: false,
                    ),
                    _ProgressStep(
                      label: _tr('measurement_page.sweep.steps.12', fallback: 'Step 12: Analyzing impulse response'),
                      isCompleted: isCompleted,
                      isActive: isAnalyzing,
                    ),

                    // Error display
                    if (isFailed) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _themeColor(
                            'app.error',
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: _themeColor('app.error'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.sweepError ?? _tr('common.unknown_error', fallback: 'Unknown error'),
                                style: TextStyle(
                                  color: _themeColor('app.error'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Debug log viewer
                    if (_showDebugLog) ...[
                      const SizedBox(height: 24),
                      _DebugLogViewer(
                        entries: _logEntries,
                        scrollController: _logScrollController,
                      ),
                    ],

                    // Action buttons
                    if (isFailed || _showDebugLog) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_showDebugLog)
                            TextButton.icon(
                              onPressed: _copyLogs,
                              icon: const Icon(Icons.copy, size: 18),
                              label: Text(
                                _tr(
                                  'measurement_page.sweep.copy_all_logs',
                                  fallback: 'Copy All Logs',
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (isFailed)
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                _tr('common.close', fallback: 'Close'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget to display debug log entries.
class _DebugLogViewer extends StatelessWidget {
  const _DebugLogViewer({
    required this.entries,
    required this.scrollController,
  });

  final List<MeasurementLogEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _themeColor(
            'measurement_page.panel_border',
          ).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Debug Log (${entries.length} entries)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                ),
                _LogSummary(entries: entries),
              ],
            ),
          ),
          // Log content
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No log entries yet...',
                      style: TextStyle(
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _LogEntryWidget(entry: entries[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Displays a summary of log levels.
class _LogSummary extends StatelessWidget {
  const _LogSummary({required this.entries});

  final List<MeasurementLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final errorCount = entries
        .where((e) => e.level == MeasurementLogLevel.error)
        .length;
    final warningCount = entries
        .where((e) => e.level == MeasurementLogLevel.warning)
        .length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errorCount > 0) ...[
          Icon(Icons.error, size: 14, color: Colors.red),
          const SizedBox(width: 2),
          Text(
            '$errorCount',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (warningCount > 0) ...[
          Icon(Icons.warning, size: 14, color: Colors.orange),
          const SizedBox(width: 2),
          Text(
            '$warningCount',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }
}

/// Individual log entry display.
class _LogEntryWidget extends StatelessWidget {
  const _LogEntryWidget({required this.entry});

  final MeasurementLogEntry entry;

  Color get _levelColor {
    switch (entry.level) {
      case MeasurementLogLevel.debug:
        return Colors.grey;
      case MeasurementLogLevel.info:
        return Colors.lightBlue;
      case MeasurementLogLevel.warning:
        return Colors.orange;
      case MeasurementLogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '[${entry.formattedTimestamp}] ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: '[${entry.levelName}] ',
              style: TextStyle(color: _levelColor, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '[${entry.source}] ',
              style: const TextStyle(color: Colors.cyan),
            ),
            TextSpan(
              text: entry.message,
              style: TextStyle(
                color: entry.level == MeasurementLogLevel.error
                    ? Colors.red[200]
                    : Colors.white,
              ),
            ),
            if (entry.data != null && entry.data!.isNotEmpty)
              TextSpan(
                text: '\n     Data: ${entry.data}',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            if (entry.error != null)
              TextSpan(
                text: '\n     Error: ${entry.error}',
                style: TextStyle(color: Colors.red[300], fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.isCompleted,
    required this.isActive,
    this.trailing,
  });

  final String label;
  final bool isCompleted;
  final bool isActive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? Colors.green
        : isActive
        ? _themeColor('measurement_page.accent')
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : isActive
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isCompleted || isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: isCompleted || isActive
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
