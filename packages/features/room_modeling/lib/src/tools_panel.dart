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

            // Step Switcher
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStepButton(
                      context,
                      label: '1. Structure',
                      step: RoomModelingStep.structure,
                      currentStep: state.currentStep,
                      isEnabled: true,
                    ),
                  ),
                  Expanded(
                    child: _buildStepButton(
                      context,
                      label: '2. Furnishing',
                      step: RoomModelingStep.furnishing,
                      currentStep: state.currentStep,
                      isEnabled: state.isRoomClosed,
                    ),
                  ),
                ],
              ),
            ),
            if (!state.isRoomClosed &&
                state.currentStep == RoomModelingStep.structure)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Close the room to proceed to furnishing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            const SizedBox(height: 16),

            if (state.currentStep == RoomModelingStep.structure) ...[
              _buildSectionTitle(context, 'Construction'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Draw walls by dragging on the canvas.\nTap a wall to select it.\nDrag endpoints to resize.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.selectedWallId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SonalyzeButton(
                    onPressed: () {
                      context
                          .read<RoomModelingBloc>()
                          .add(const DeleteSelectedWall());
                    },
                    variant: SonalyzeButtonVariant.filled,
                    // color: Theme.of(context).colorScheme.error, // If supported
                    child: const Text('Delete Selected Wall'),
                  ),
                ),
            ] else ...[
              _buildFurnitureMenu(context, state),
            ],

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

  Widget _buildStepButton(
    BuildContext context, {
    required String label,
    required RoomModelingStep step,
    required RoomModelingStep currentStep,
    required bool isEnabled,
  }) {
    final isSelected = step == currentStep;
    return InkWell(
      onTap: isEnabled
          ? () {
              context.read<RoomModelingBloc>().add(StepChanged(step));
            }
          : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : (isEnabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
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

  Widget _buildFurnitureMenu(BuildContext context, RoomModelingState state) {
    return PopupMenuButton<RoomModelingTool>(
      initialValue: state.activeTool,
      onSelected: (tool) {
        context.read<RoomModelingBloc>().add(ToolSelected(tool));
      },
      itemBuilder: (context) => [
        _buildMenuHeader('Openings'),
        _buildMenuItem(
            context, RoomModelingTool.door, 'Door', Icons.door_front_door),
        _buildMenuItem(
            context, RoomModelingTool.window, 'Window', Icons.window),
        const PopupMenuDivider(),
        _buildMenuHeader('Furniture'),
        _buildMenuItem(context, RoomModelingTool.chair, 'Chair', Icons.chair),
        _buildMenuItem(
            context, RoomModelingTool.table, 'Table', Icons.table_bar),
        _buildMenuItem(context, RoomModelingTool.sofa, 'Sofa', Icons.weekend),
        _buildMenuItem(context, RoomModelingTool.bed, 'Bed', Icons.bed),
        const PopupMenuDivider(),
        _buildMenuHeader('Bathroom & Kitchen'),
        _buildMenuItem(
            context, RoomModelingTool.bathtub, 'Bathtub', Icons.bathtub),
        _buildMenuItem(context, RoomModelingTool.toilet, 'Toilet', Icons.wc),
        _buildMenuItem(context, RoomModelingTool.sink, 'Sink', Icons.wash),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_getToolIcon(state.activeTool), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getToolLabel(state.activeTool),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<RoomModelingTool> _buildMenuHeader(String title) {
    return PopupMenuItem<RoomModelingTool>(
      enabled: false,
      height: 32,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  PopupMenuItem<RoomModelingTool> _buildMenuItem(
    BuildContext context,
    RoomModelingTool tool,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem<RoomModelingTool>(
      value: tool,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  String _getToolLabel(RoomModelingTool tool) {
    switch (tool) {
      case RoomModelingTool.door:
        return 'Door';
      case RoomModelingTool.window:
        return 'Window';
      case RoomModelingTool.chair:
        return 'Chair';
      case RoomModelingTool.table:
        return 'Table';
      case RoomModelingTool.sofa:
        return 'Sofa';
      case RoomModelingTool.bed:
        return 'Bed';
      case RoomModelingTool.bathtub:
        return 'Bathtub';
      case RoomModelingTool.toilet:
        return 'Toilet';
      case RoomModelingTool.sink:
        return 'Sink';
      default:
        return 'Select Tool';
    }
  }

  IconData _getToolIcon(RoomModelingTool tool) {
    switch (tool) {
      case RoomModelingTool.door:
        return Icons.door_front_door;
      case RoomModelingTool.window:
        return Icons.window;
      case RoomModelingTool.chair:
        return Icons.chair;
      case RoomModelingTool.table:
        return Icons.table_bar;
      case RoomModelingTool.sofa:
        return Icons.weekend;
      case RoomModelingTool.bed:
        return Icons.bed;
      case RoomModelingTool.bathtub:
        return Icons.bathtub;
      case RoomModelingTool.toilet:
        return Icons.wc;
      case RoomModelingTool.sink:
        return Icons.wash;
      default:
        return Icons.build;
    }
  }
}
