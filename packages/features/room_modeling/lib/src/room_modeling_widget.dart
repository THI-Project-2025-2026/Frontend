import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'tools_panel.dart';
import 'room_plan_canvas.dart';

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
        Expanded(child: SonalyzeSurface(child: const RoomPlanCanvas())),
      ],
    );
  }
}
