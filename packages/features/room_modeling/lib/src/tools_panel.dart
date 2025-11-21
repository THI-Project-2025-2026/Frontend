import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'bloc/room_modeling_event.dart';
import 'bloc/room_modeling_state.dart';

class ToolsPanel extends StatelessWidget {
  const ToolsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tools', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Structure'),
            _buildToolButton(
              context,
              label: 'Wall',
              icon: Icons.crop_square,
              tool: RoomModelingTool.wall,
              isSelected: state.activeTool == RoomModelingTool.wall,
              isEnabled: !state.isRoomClosed,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Openings'),
            _buildToolButton(
              context,
              label: 'Door',
              icon: Icons.door_front_door,
              tool: RoomModelingTool.door,
              isSelected: state.activeTool == RoomModelingTool.door,
              isEnabled: state.isRoomClosed,
            ),
            _buildToolButton(
              context,
              label: 'Window',
              icon: Icons.window,
              tool: RoomModelingTool.window,
              isSelected: state.activeTool == RoomModelingTool.window,
              isEnabled: state.isRoomClosed,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Furniture'),
            _buildToolButton(
              context,
              label: 'Chair',
              icon: Icons.chair,
              tool: RoomModelingTool.chair,
              isSelected: state.activeTool == RoomModelingTool.chair,
              isEnabled: state.isRoomClosed,
            ),
            _buildToolButton(
              context,
              label: 'Table',
              icon: Icons.table_bar,
              tool: RoomModelingTool.table,
              isSelected: state.activeTool == RoomModelingTool.table,
              isEnabled: state.isRoomClosed,
            ),
            const Spacer(),
            SonalyzeButton(
              onPressed: () {
                context.read<RoomModelingBloc>().add(const ClearRoom());
              },
              variant: SonalyzeButtonVariant.text,
              child: const Text('Clear Room'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required RoomModelingTool tool,
    required bool isSelected,
    required bool isEnabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SonalyzeButton(
        icon: Icon(icon, size: 18),
        onPressed: isEnabled
            ? () {
                context.read<RoomModelingBloc>().add(ToolSelected(tool));
              }
            : null,
        variant: isSelected
            ? SonalyzeButtonVariant.filled
            : SonalyzeButtonVariant.outlined,
        child: Text(label),
      ),
    );
  }
}
