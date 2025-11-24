import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'bloc/room_modeling_event.dart';
import 'bloc/room_modeling_state.dart';
import 'models/furniture.dart';

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
              const SizedBox(height: 12),
              _RoomStructureOptions(roomHeight: state.roomHeightMeters),
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
              ..._buildSelectedFurnitureEditor(context, state),
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

  List<Widget> _buildSelectedFurnitureEditor(
    BuildContext context,
    RoomModelingState state,
  ) {
    final selectedFurniture = _findSelectedFurniture(state);
    if (selectedFurniture == null) {
      return const <Widget>[];
    }

    return [
      const SizedBox(height: 16),
      _buildSectionTitle(context, 'Selected Furniture'),
      _FurnitureEditor(furniture: selectedFurniture),
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: SonalyzeButton(
          onPressed: () {
            context
                .read<RoomModelingBloc>()
                .add(const DeleteSelectedFurniture());
          },
          variant: SonalyzeButtonVariant.filled,
          child: const Text('Delete Selected Item'),
        ),
      ),
    ];
  }

  Furniture? _findSelectedFurniture(RoomModelingState state) {
    final selectedId = state.selectedFurnitureId;
    if (selectedId == null) {
      return null;
    }

    try {
      return state.furniture.firstWhere((f) => f.id == selectedId);
    } catch (_) {
      return null;
    }
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

class _FurnitureEditor extends StatefulWidget {
  final Furniture furniture;

  const _FurnitureEditor({required this.furniture});

  @override
  State<_FurnitureEditor> createState() => _FurnitureEditorState();
}

class _FurnitureEditorState extends State<_FurnitureEditor> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _rotationController;
  late final TextEditingController _sillHeightController;
  late final TextEditingController _windowHeightController;

  bool get _isOpening => widget.furniture.isOpening;
  bool get _isWindow => widget.furniture.type == FurnitureType.window;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _rotationController = TextEditingController();
    _sillHeightController = TextEditingController();
    _windowHeightController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _FurnitureEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.furniture != oldWidget.furniture ||
        widget.furniture.size != oldWidget.furniture.size ||
        widget.furniture.rotation != oldWidget.furniture.rotation ||
        widget.furniture.sillHeightMeters !=
            oldWidget.furniture.sillHeightMeters ||
        widget.furniture.openingHeightMeters !=
            oldWidget.furniture.openingHeightMeters) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _rotationController.dispose();
    _sillHeightController.dispose();
    _windowHeightController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _widthController.text = _formatMeters(widget.furniture.size.width);
    _heightController.text = _formatMeters(widget.furniture.size.height);
    _rotationController.text = _formatDegrees(widget.furniture.rotation);
    final sill = widget.furniture.sillHeightMeters ??
        Furniture.defaultWindowSillHeightMeters;
    final winHeight = widget.furniture.openingHeightMeters ??
        Furniture.defaultWindowHeightMeters;
    _sillHeightController.text = sill.toStringAsFixed(2);
    _windowHeightController.text = winHeight.toStringAsFixed(2);
  }

  String _formatMeters(double value) {
    final meters = value / RoomModelingBloc.pixelsPerMeter;
    return meters.toStringAsFixed(2);
  }

  String _formatDegrees(double radians) {
    final degrees = (radians * 180 / math.pi) % 360;
    final normalized = degrees < 0 ? degrees + 360 : degrees;
    return normalized.toStringAsFixed(1);
  }

  void _handleWidthChanged(String value) {
    final meters = double.tryParse(value);
    if (meters == null) return;

    final widthPx = meters * RoomModelingBloc.pixelsPerMeter;
    context.read<RoomModelingBloc>().add(
          UpdateSelectedFurniture(
            size: Size(widthPx, widget.furniture.size.height),
          ),
        );
  }

  void _handleHeightChanged(String value) {
    if (_isOpening) return;
    final meters = double.tryParse(value);
    if (meters == null) return;

    final heightPx = meters * RoomModelingBloc.pixelsPerMeter;
    context.read<RoomModelingBloc>().add(
          UpdateSelectedFurniture(
            size: Size(widget.furniture.size.width, heightPx),
          ),
        );
  }

  void _handleRotationChanged(String value) {
    final degrees = double.tryParse(value);
    if (degrees == null) return;

    final radians = degrees * math.pi / 180;
    context
        .read<RoomModelingBloc>()
        .add(UpdateSelectedFurniture(rotation: radians));
  }

  void _handleSillHeightChanged(String value) {
    final meters = double.tryParse(value);
    if (meters == null) return;

    context
        .read<RoomModelingBloc>()
        .add(UpdateSelectedFurniture(sillHeightMeters: meters));
  }

  void _handleWindowHeightChanged(String value) {
    final meters = double.tryParse(value);
    if (meters == null) return;

    context
        .read<RoomModelingBloc>()
        .add(UpdateSelectedFurniture(openingHeightMeters: meters));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatFurnitureLabel(widget.furniture.type),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            context,
            label: 'Length',
            controller: _widthController,
            onChanged: _handleWidthChanged,
            suffixText: 'm',
            textInputAction:
                _isOpening ? TextInputAction.done : TextInputAction.next,
          ),
          if (_isOpening) ...[
            const SizedBox(height: 8),
            Text(
              'Doors and windows keep a fixed thickness and rotation.',
              style: theme.textTheme.bodySmall,
            ),
            if (_isWindow) ...[
              const SizedBox(height: 12),
              _buildNumberField(
                context,
                label: 'Sill height',
                controller: _sillHeightController,
                onChanged: _handleSillHeightChanged,
                suffixText: 'm',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                context,
                label: 'Window height',
                controller: _windowHeightController,
                onChanged: _handleWindowHeightChanged,
                suffixText: 'm',
                textInputAction: TextInputAction.done,
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            _buildNumberField(
              context,
              label: 'Width',
              controller: _heightController,
              onChanged: _handleHeightChanged,
              suffixText: 'm',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              context,
              label: 'Rotation',
              controller: _rotationController,
              onChanged: _handleRotationChanged,
              suffixText: '°',
              textInputAction: TextInputAction.done,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String? suffixText,
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
      ),
      onChanged: onChanged,
    );
  }

  String _formatFurnitureLabel(FurnitureType type) {
    final raw = type.name.replaceAll('_', ' ');
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _RoomStructureOptions extends StatefulWidget {
  final double roomHeight;

  const _RoomStructureOptions({required this.roomHeight});

  @override
  State<_RoomStructureOptions> createState() => _RoomStructureOptionsState();
}

class _RoomStructureOptionsState extends State<_RoomStructureOptions> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _RoomStructureOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.roomHeight - oldWidget.roomHeight).abs() > 0.001) {
      _syncController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncController() {
    _controller.text = widget.roomHeight.toStringAsFixed(2);
  }

  void _handleHeightChanged(String value) {
    final meters = double.tryParse(value);
    if (meters == null) return;

    context.read<RoomModelingBloc>().add(RoomHeightChanged(meters));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room options',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Room height',
              suffixText: 'm',
              helperText:
                  'Default ${RoomModelingState.defaultRoomHeightMeters.toStringAsFixed(2)} m',
            ),
            textInputAction: TextInputAction.done,
            onChanged: _handleHeightChanged,
          ),
        ],
      ),
    );
  }
}
