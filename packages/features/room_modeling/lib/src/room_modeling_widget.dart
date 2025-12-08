import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'tools_panel.dart';
import 'room_plan_canvas.dart';
import 'room_3d_preview.dart';
import 'room_modeling_l10n.dart';

class RoomModelingWidget extends StatelessWidget {
  const RoomModelingWidget({super.key, this.bloc, this.hideToolsPanel = false});

  /// Optional external bloc. If not provided, creates its own.
  final RoomModelingBloc? bloc;

  /// Whether to hide the tools panel and show only the canvas.
  final bool hideToolsPanel;

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<RoomModelingBloc>.value(
        value: bloc!,
        child: RoomModelingView(hideToolsPanel: hideToolsPanel),
      );
    }
    return BlocProvider(
      create: (context) => RoomModelingBloc(),
      child: RoomModelingView(hideToolsPanel: hideToolsPanel),
    );
  }
}

class RoomModelingView extends StatelessWidget {
  const RoomModelingView({super.key, this.hideToolsPanel = false});

  final bool hideToolsPanel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Tools Panel with animated size
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hideToolsPanel ? 0.0 : 1.0,
            child: SizedBox(
              width: hideToolsPanel ? 0 : 250,
              child: hideToolsPanel
                  ? null
                  : SonalyzeSurface(child: const ToolsPanel()),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SizedBox(width: hideToolsPanel ? 0 : 16),
        ),
        // Right Room Plan
        Expanded(
          child: SonalyzeSurface(
            child: Stack(
              children: [
                const RoomPlanCanvas(),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: RoomModelingColors.color(
                      'preview.button_background',
                    ),
                    foregroundColor: RoomModelingColors.color(
                      'preview.button_foreground',
                    ),
                    tooltip: RoomModelingL10n.text('preview.tooltip'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: 1200, maxHeight: 800),
                            child: const Room3DPreview(),
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.view_in_ar),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
