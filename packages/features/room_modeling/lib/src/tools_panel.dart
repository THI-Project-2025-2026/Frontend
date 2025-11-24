import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'bloc/room_modeling_bloc.dart';
import 'bloc/room_modeling_event.dart';
import 'bloc/room_modeling_state.dart';
import 'models/furniture.dart';
import 'room_modeling_l10n.dart';

class ToolsPanel extends StatelessWidget {
  const ToolsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      builder: (context, state) {
        final structureLabel = RoomModelingL10n.text('tools.steps.structure');
        final furnishingLabel = RoomModelingL10n.text('tools.steps.furnishing');
        final showStructureGuidance = !state.isRoomClosed &&
            state.currentStep == RoomModelingStep.structure;
        final warningColor = RoomModelingColors.color('stepper.warning_text');
        final stepperBackground =
            RoomModelingColors.color('stepper.background');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              RoomModelingL10n.text('tools.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Step Switcher
            Container(
              decoration: BoxDecoration(
                color: stepperBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStepButton(
                      context,
                      label: structureLabel,
                      step: RoomModelingStep.structure,
                      currentStep: state.currentStep,
                      isEnabled: true,
                    ),
                  ),
                  Expanded(
                    child: _buildStepButton(
                      context,
                      label: furnishingLabel,
                      step: RoomModelingStep.furnishing,
                      currentStep: state.currentStep,
                      isEnabled: state.isRoomClosed,
                    ),
                  ),
                ],
              ),
            ),
            if (showStructureGuidance)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  RoomModelingL10n.text('tools.close_room_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: warningColor,
                      ),
                ),
              ),
            const SizedBox(height: 16),

            if (state.currentStep == RoomModelingStep.structure) ...[
              _buildSectionTitle(
                context,
                RoomModelingL10n.text('tools.construction_title'),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  RoomModelingL10n.text('tools.construction_helper'),
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
                    child: Text(
                      RoomModelingL10n.text('tools.delete_wall'),
                    ),
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
              child: Text(RoomModelingL10n.text('tools.clear_room')),
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
    final selectedBackground =
        RoomModelingColors.color('stepper.selected_background');
    final unselectedBackground =
        RoomModelingColors.color('stepper.unselected_background');
    final selectedText = RoomModelingColors.color('stepper.selected_text');
    final defaultText = RoomModelingColors.color('stepper.text');
    final disabledText = RoomModelingColors.color('stepper.disabled_text');

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
          color: isSelected ? selectedBackground : unselectedBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? selectedText
                    : (isEnabled ? defaultText : disabledText),
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: RoomModelingColors.color('section.title'),
            ),
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
      _buildSectionTitle(
        context,
        RoomModelingL10n.text('tools.selected_furniture'),
      ),
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
          child: Text(RoomModelingL10n.text('tools.delete_item')),
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
    final openingsLabel = RoomModelingL10n.text('tools.menu.openings');
    final furnitureLabel = RoomModelingL10n.text('tools.menu.furniture');
    final bathKitchenLabel = RoomModelingL10n.text('tools.menu.bath_kitchen');

    return PopupMenuButton<RoomModelingTool>(
      initialValue: state.activeTool,
      onSelected: (tool) {
        context.read<RoomModelingBloc>().add(ToolSelected(tool));
      },
      itemBuilder: (context) => [
        _buildMenuHeader(openingsLabel),
        _buildMenuItem(
          context,
          RoomModelingTool.door,
          RoomModelingL10n.text('tools.menu.items.door'),
          Icons.door_front_door,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.window,
          RoomModelingL10n.text('tools.menu.items.window'),
          Icons.window,
        ),
        const PopupMenuDivider(),
        _buildMenuHeader(furnitureLabel),
        _buildMenuItem(
          context,
          RoomModelingTool.chair,
          RoomModelingL10n.text('tools.menu.items.chair'),
          Icons.chair,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.table,
          RoomModelingL10n.text('tools.menu.items.table'),
          Icons.table_bar,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.sofa,
          RoomModelingL10n.text('tools.menu.items.sofa'),
          Icons.weekend,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.bed,
          RoomModelingL10n.text('tools.menu.items.bed'),
          Icons.bed,
        ),
        const PopupMenuDivider(),
        _buildMenuHeader(bathKitchenLabel),
        _buildMenuItem(
          context,
          RoomModelingTool.bathtub,
          RoomModelingL10n.text('tools.menu.items.bathtub'),
          Icons.bathtub,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.toilet,
          RoomModelingL10n.text('tools.menu.items.toilet'),
          Icons.wc,
        ),
        _buildMenuItem(
          context,
          RoomModelingTool.sink,
          RoomModelingL10n.text('tools.menu.items.sink'),
          Icons.wash,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: RoomModelingColors.color('menu.border')),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: RoomModelingColors.color('menu.header_text'),
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
          Icon(
            icon,
            size: 20,
            color: RoomModelingColors.color('menu.icon'),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  String _getToolLabel(RoomModelingTool tool) {
    final key = 'tools.menu.items.${tool.name}';
    final label = RoomModelingL10n.text(key);
    if (label == key) {
      return RoomModelingL10n.text('tools.menu.placeholder');
    }
    return label;
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
    final cardBackground = RoomModelingColors.color('card.background');
    final cardBorder = RoomModelingColors.color('card.border');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RoomModelingL10n.text(
              'tools.menu.items.${widget.furniture.type.name}',
            ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            context,
            label: RoomModelingL10n.text('editor.length'),
            controller: _widthController,
            onChanged: _handleWidthChanged,
            suffixText: RoomModelingL10n.metersSuffix(),
            textInputAction:
                _isOpening ? TextInputAction.done : TextInputAction.next,
          ),
          if (_isOpening) ...[
            const SizedBox(height: 8),
            Text(
              RoomModelingL10n.text('editor.opening_hint'),
              style: theme.textTheme.bodySmall,
            ),
            if (_isWindow) ...[
              const SizedBox(height: 12),
              _buildNumberField(
                context,
                label: RoomModelingL10n.text('editor.sill_height'),
                controller: _sillHeightController,
                onChanged: _handleSillHeightChanged,
                suffixText: RoomModelingL10n.metersSuffix(),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                context,
                label: RoomModelingL10n.text('editor.window_height'),
                controller: _windowHeightController,
                onChanged: _handleWindowHeightChanged,
                suffixText: RoomModelingL10n.metersSuffix(),
                textInputAction: TextInputAction.done,
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            _buildNumberField(
              context,
              label: RoomModelingL10n.text('editor.width'),
              controller: _heightController,
              onChanged: _handleHeightChanged,
              suffixText: RoomModelingL10n.metersSuffix(),
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              context,
              label: RoomModelingL10n.text('editor.rotation'),
              controller: _rotationController,
              onChanged: _handleRotationChanged,
              suffixText: RoomModelingL10n.degreesSuffix(),
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
    final cardBackground = RoomModelingColors.color('card.background');
    final cardBorder = RoomModelingColors.color('card.border');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RoomModelingL10n.text('structure.options_title'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: RoomModelingL10n.text('structure.room_height_label'),
              suffixText: RoomModelingL10n.metersSuffix(),
              helperText: RoomModelingL10n.format(
                'structure.room_height_helper',
                {
                  'value': RoomModelingState.defaultRoomHeightMeters
                      .toStringAsFixed(2),
                },
              ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: _handleHeightChanged,
          ),
        ],
      ),
    );
  }
}
