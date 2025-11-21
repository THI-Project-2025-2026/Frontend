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
              _buildSectionTitle(context, 'Openings'),
              _buildToolButton(
                context,
                label: 'Door',
                icon: Icons.door_front_door,
                tool: RoomModelingTool.door,
                isSelected: state.activeTool == RoomModelingTool.door,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Window',
                icon: Icons.window,
                tool: RoomModelingTool.window,
                isSelected: state.activeTool == RoomModelingTool.window,
                isEnabled: true,
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Furniture'),
              _buildToolButton(
                context,
                label: 'Chair',
                icon: Icons.chair,
                tool: RoomModelingTool.chair,
                isSelected: state.activeTool == RoomModelingTool.chair,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Table',
                icon: Icons.table_bar,
                tool: RoomModelingTool.table,
                isSelected: state.activeTool == RoomModelingTool.table,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Sofa',
                icon: Icons.weekend, // weekend is often used for sofa
                tool: RoomModelingTool.sofa,
                isSelected: state.activeTool == RoomModelingTool.sofa,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Bed',
                icon: Icons.bed,
                tool: RoomModelingTool.bed,
                isSelected: state.activeTool == RoomModelingTool.bed,
                isEnabled: true,
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Bathroom & Kitchen'),
              _buildToolButton(
                context,
                label: 'Bathtub',
                icon: Icons.bathtub,
                tool: RoomModelingTool.bathtub,
                isSelected: state.activeTool == RoomModelingTool.bathtub,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Toilet',
                icon: Icons
                    .wc, // Or Icons.bathroom if available, but wc is standard
                tool: RoomModelingTool.toilet,
                isSelected: state.activeTool == RoomModelingTool.toilet,
                isEnabled: true,
              ),
              _buildToolButton(
                context,
                label: 'Sink',
                icon: Icons.wash,
                tool: RoomModelingTool.sink,
                isSelected: state.activeTool == RoomModelingTool.sink,
                isEnabled: true,
              ),
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
