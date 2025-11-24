import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'tools_panel.dart';
import 'room_plan_canvas.dart';
import 'room_3d_preview.dart';
import 'room_modeling_l10n.dart';

class RoomModelingWidget extends StatelessWidget {
  const RoomModelingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RoomModelingBloc(),
      child: const RoomModelingView(),
    );
  }
}

class RoomModelingView extends StatelessWidget {
  const RoomModelingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Tools Panel
        SizedBox(width: 250, child: SonalyzeSurface(child: const ToolsPanel())),
        const SizedBox(width: 16),
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
