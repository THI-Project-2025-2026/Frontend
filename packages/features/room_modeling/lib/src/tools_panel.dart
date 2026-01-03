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
        if (state.currentStep == RoomModelingStep.structure) {
          // Structure step: use scrollable layout to handle overflow when wall is selected
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                RoomModelingL10n.text('tools.title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            child: Text(
                              RoomModelingL10n.text('tools.delete_wall'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SonalyzeButton(
                        onPressed: () {
                          context
                              .read<RoomModelingBloc>()
                              .add(const ClearRoom());
                        },
                        variant: SonalyzeButtonVariant.text,
                        child: Text(RoomModelingL10n.text('tools.clear_room')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        // Furnishing and Audio steps: use existing layout
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              RoomModelingL10n.text('tools.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (state.currentStep == RoomModelingStep.furnishing) ...[
              _buildFurnitureMenu(context, state),
              ..._buildSelectedFurnitureEditor(context, state),
            ] else ...[
              _buildAudioMenu(context, state),
              ..._buildSelectedFurnitureEditor(context, state),
            ],
            const SizedBox(height: 16),
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
        child: Row(
          children: [
            Expanded(
              child: SonalyzeButton(
                onPressed: () {
                  context.read<RoomModelingBloc>().add(
                        const FurnitureSelected(null),
                      );
                },
                variant: SonalyzeButtonVariant.outlined,
                child: Text(RoomModelingL10n.text('editor.apply')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
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
          ],
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
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolCategory(
              context,
              state,
              RoomModelingL10n.text('tools.menu.openings'),
              [
                _ToolItem(RoomModelingTool.door, Icons.door_front_door),
                _ToolItem(RoomModelingTool.window, Icons.window),
              ],
            ),
            const SizedBox(height: 16),
            _buildToolCategory(
              context,
              state,
              RoomModelingL10n.text('tools.menu.furniture'),
              [
                _ToolItem(RoomModelingTool.chair, Icons.chair),
                _ToolItem(RoomModelingTool.deskchair, Icons.chair_alt),
                _ToolItem(RoomModelingTool.table, Icons.table_bar),
                _ToolItem(RoomModelingTool.sofa, Icons.weekend),
                _ToolItem(RoomModelingTool.bed, Icons.bed),
                _ToolItem(RoomModelingTool.closet, Icons.checkroom),
                _ToolItem(RoomModelingTool.desk, Icons.desk),
                _ToolItem(RoomModelingTool.shelf, Icons.shelves),
              ],
            ),
            const SizedBox(height: 16),
            _buildToolCategory(
              context,
              state,
              RoomModelingL10n.text('tools.menu.bath_kitchen'),
              [
                _ToolItem(RoomModelingTool.bathtub, Icons.bathtub),
                _ToolItem(RoomModelingTool.toilet, Icons.wc),
                _ToolItem(RoomModelingTool.sink, Icons.wash),
                _ToolItem(RoomModelingTool.shower, Icons.shower),
                _ToolItem(RoomModelingTool.stove, Icons.countertops),
                _ToolItem(RoomModelingTool.fridge, Icons.kitchen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMenu(BuildContext context, RoomModelingState state) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                RoomModelingL10n.text('tools.menu.audio'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: RoomModelingColors.color('menu.header_text'),
                    ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToolItem(RoomModelingTool.speaker, Icons.speaker_group),
                _ToolItem(RoomModelingTool.microphone, Icons.mic),
              ].map((item) => _buildToolButton(context, state, item)).toList(),
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final helper = RoomModelingL10n.text('tools.audio.helper');
              final resolved = helper == 'tools.audio.helper'
                  ? 'Place at least one speaker and one microphone to continue.'
                  : helper;
              return Text(
                resolved,
                style: Theme.of(context).textTheme.bodySmall,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCategory(
    BuildContext context,
    RoomModelingState state,
    String title,
    List<_ToolItem> tools,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: RoomModelingColors.color('menu.header_text'),
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tools
              .map((item) => _buildToolButton(context, state, item))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    RoomModelingState state,
    _ToolItem item,
  ) {
    final isActive = state.activeTool == item.tool;
    final label = _getToolLabel(item.tool);

    return InkWell(
      onTap: () {
        context.read<RoomModelingBloc>().add(ToolSelected(item.tool));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? RoomModelingColors.color('menu.active_background')
              : RoomModelingColors.color('menu.background'),
          border: Border.all(
            color: isActive
                ? RoomModelingColors.color('menu.active_border')
                : RoomModelingColors.color('menu.border'),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isActive
                  ? RoomModelingColors.color('menu.active_icon')
                  : RoomModelingColors.color('menu.icon'),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? RoomModelingColors.color('menu.active_text')
                          : RoomModelingColors.color('menu.text'),
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getToolLabel(RoomModelingTool tool) {
    final key = 'tools.menu.items.${tool.name}';
    final label = RoomModelingL10n.text(key);
    if (label == key) {
      switch (tool) {
        case RoomModelingTool.speaker:
          return 'Speaker';
        case RoomModelingTool.microphone:
          return 'Microphone';
        default:
          return RoomModelingL10n.text('tools.menu.placeholder');
      }
    }
    return label;
  }
}

class _ToolItem {
  final RoomModelingTool tool;
  final IconData icon;

  const _ToolItem(this.tool, this.icon);
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
  late final TextEditingController _verticalHeightController;
  late final TextEditingController _sillHeightController;
  late final TextEditingController _windowHeightController;

  bool get _isOpening => widget.furniture.isOpening;
  bool get _isWindow => widget.furniture.type == FurnitureType.window;
  bool get _isDevice => widget.furniture.isDevice;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(
      text: (widget.furniture.size.width / 50).toStringAsFixed(2),
    );
    _heightController = TextEditingController(
      text: (widget.furniture.size.height / 50).toStringAsFixed(2),
    );
    // Vertical furniture height (meters): use explicit value if set, otherwise fall back to defaults
    final initialVerticalHeight = (widget.furniture.heightMeters ??
        _defaultFurnitureHeightMeters(widget.furniture.type));
    _verticalHeightController = TextEditingController(
      text: initialVerticalHeight.toStringAsFixed(2),
    );
    _sillHeightController = TextEditingController(
      text: (widget.furniture.sillHeightMeters ??
              Furniture.defaultWindowSillHeightMeters)
          .toStringAsFixed(2),
    );
    _windowHeightController = TextEditingController(
      text: (widget.furniture.openingHeightMeters ??
              Furniture.defaultWindowHeightMeters)
          .toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _verticalHeightController.dispose();
    _sillHeightController.dispose();
    _windowHeightController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FurnitureEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reset controllers if a different furniture item is selected
    if (oldWidget.furniture.id != widget.furniture.id) {
      // Reset controllers to reflect the new furniture's values
      _widthController.text =
          (widget.furniture.size.width / RoomModelingBloc.pixelsPerMeter)
              .toStringAsFixed(2);
      _heightController.text =
          (widget.furniture.size.height / RoomModelingBloc.pixelsPerMeter)
              .toStringAsFixed(2);
      final initialVerticalHeight = (widget.furniture.heightMeters ??
          _defaultFurnitureHeightMeters(widget.furniture.type));
      _verticalHeightController.text = initialVerticalHeight.toStringAsFixed(2);
      _sillHeightController.text = (widget.furniture.sillHeightMeters ??
              Furniture.defaultWindowSillHeightMeters)
          .toStringAsFixed(2);
      _windowHeightController.text = (widget.furniture.openingHeightMeters ??
              Furniture.defaultWindowHeightMeters)
          .toStringAsFixed(2);
    } else if (widget.furniture.id == oldWidget.furniture.id) {
      // Same furniture item was updated (e.g., by canvas drag or event).
      // Update controllers only if the actual value differs significantly from user's input.
      _syncControllerIfNeeded(_widthController,
          widget.furniture.size.width / RoomModelingBloc.pixelsPerMeter);
      _syncControllerIfNeeded(_heightController,
          widget.furniture.size.height / RoomModelingBloc.pixelsPerMeter);
      _syncControllerIfNeeded(
          _verticalHeightController,
          widget.furniture.heightMeters ??
              _defaultFurnitureHeightMeters(widget.furniture.type));
      if (widget.furniture.type == FurnitureType.window) {
        _syncControllerIfNeeded(
            _sillHeightController,
            widget.furniture.sillHeightMeters ??
                Furniture.defaultWindowSillHeightMeters);
        _syncControllerIfNeeded(
            _windowHeightController,
            widget.furniture.openingHeightMeters ??
                Furniture.defaultWindowHeightMeters);
      }
    }
  }

  void _syncControllerIfNeeded(TextEditingController controller, double value) {
    final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
    if (parsed == null || (parsed - value).abs() > 0.01) {
      controller.text = value.toStringAsFixed(2);
    }
  }

  void _handleWidthChanged(String value) {
    final sanitized = value.replaceAll(',', '.');
    final meters = double.tryParse(sanitized);
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
    final sanitized = value.replaceAll(',', '.');
    final meters = double.tryParse(sanitized);
    if (meters == null) return;

    final heightPx = meters * RoomModelingBloc.pixelsPerMeter;
    context.read<RoomModelingBloc>().add(
          UpdateSelectedFurniture(
            size: Size(widget.furniture.size.width, heightPx),
          ),
        );
  }

  void _handleVerticalHeightChanged(String value) {
    final sanitized = value.replaceAll(',', '.');
    final meters = double.tryParse(sanitized);
    if (meters == null) return;

    context
        .read<RoomModelingBloc>()
        .add(UpdateSelectedFurniture(heightMeters: meters));
  }

  double _defaultFurnitureHeightMeters(FurnitureType t) {
    switch (t) {
      case FurnitureType.table:
        return 0.75;
      case FurnitureType.chair:
        return 1.0;
      case FurnitureType.sofa:
        return 0.8;
      case FurnitureType.bed:
        return 0.6;
      case FurnitureType.bathtub:
        return 0.6;
      case FurnitureType.toilet:
        return 0.8;
      case FurnitureType.sink:
        return 0.9;
      case FurnitureType.door:
      case FurnitureType.window:
        return 0.0;
      case FurnitureType.deskchair:
        return 1.0;
      case FurnitureType.closet:
        return 2.0;
      case FurnitureType.desk:
        return 0.75;
      case FurnitureType.shelf:
        return 1.8;
      case FurnitureType.stove:
        return 0.9;
      case FurnitureType.fridge:
        return 1.8;
      case FurnitureType.shower:
        return 2.2;
      case FurnitureType.speaker:
        return 1.4;
      case FurnitureType.microphone:
        return 1.2;
    }
  }

  void _handleSillHeightChanged(String value) {
    final sanitized = value.replaceAll(',', '.');
    final meters = double.tryParse(sanitized);
    if (meters == null) return;

    context
        .read<RoomModelingBloc>()
        .add(UpdateSelectedFurniture(sillHeightMeters: meters));
  }

  void _handleWindowHeightChanged(String value) {
    final sanitized = value.replaceAll(',', '.');
    final meters = double.tryParse(sanitized);
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
          if (!_isDevice)
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
              const SizedBox(height: 8),
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
            if (!_isDevice) ...[
              const SizedBox(height: 8),
              _buildNumberField(
                context,
                label: RoomModelingL10n.text('editor.width'),
                controller: _heightController,
                onChanged: _handleHeightChanged,
                suffixText: RoomModelingL10n.metersSuffix(),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              _buildNumberField(
                context,
                label: RoomModelingL10n.text('editor.height'),
                controller: _verticalHeightController,
                onChanged: _handleVerticalHeightChanged,
                suffixText: RoomModelingL10n.metersSuffix(),
                textInputAction: TextInputAction.done,
              ),
            ] else ...[
              const SizedBox(height: 8),
              _buildNumberField(
                context,
                label: RoomModelingL10n.text('editor.height'),
                controller: _verticalHeightController,
                onChanged: _handleVerticalHeightChanged,
                suffixText: RoomModelingL10n.metersSuffix(),
                textInputAction: TextInputAction.done,
              ),
            ],
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
    required String suffixText,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  late final TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _heightController =
        TextEditingController(text: widget.roomHeight.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _handleHeightChanged(String value) {
    final meters = double.tryParse(value);
    if (meters == null || meters <= 0) return;
    context.read<RoomModelingBloc>().add(RoomHeightChanged(meters));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomModelingBloc, RoomModelingState>(
      buildWhen: (prev, curr) =>
          prev.availableMaterials != curr.availableMaterials ||
          prev.roomMaterials != curr.roomMaterials ||
          prev.isMaterialsLoading != curr.isMaterialsLoading,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RoomModelingL10n.text('structure.options_title'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: RoomModelingColors.color('section.title'),
                  ),
            ),
            const SizedBox(height: 8),
            // Material Selection Section
            if (state.availableMaterials.isNotEmpty) ...[
              _buildMaterialDropdown(
                context,
                label: RoomModelingL10n.text('structure.wall_material_label'),
                value: state.roomMaterials.wallMaterial,
                materials: state.availableMaterials,
                onChanged: (material) {
                  context
                      .read<RoomModelingBloc>()
                      .add(WallMaterialChanged(material));
                },
              ),
              const SizedBox(height: 8),
              _buildMaterialDropdown(
                context,
                label: RoomModelingL10n.text('structure.floor_material_label'),
                value: state.roomMaterials.floorMaterial,
                materials: state.availableMaterials,
                onChanged: (material) {
                  context
                      .read<RoomModelingBloc>()
                      .add(FloorMaterialChanged(material));
                },
              ),
              const SizedBox(height: 8),
              _buildMaterialDropdown(
                context,
                label:
                    RoomModelingL10n.text('structure.ceiling_material_label'),
                value: state.roomMaterials.ceilingMaterial,
                materials: state.availableMaterials,
                onChanged: (material) {
                  context
                      .read<RoomModelingBloc>()
                      .add(CeilingMaterialChanged(material));
                },
              ),
              const SizedBox(height: 12),
            ] else if (state.isMaterialsLoading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
            // Room Height Field
            TextField(
              controller: _heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: RoomModelingL10n.text('structure.room_height_label'),
                suffixText: RoomModelingL10n.metersSuffix(),
                helperText:
                    RoomModelingL10n.text('structure.room_height_helper')
                        .replaceAll(
                  '{value}',
                  RoomModelingState.defaultRoomHeightMeters.toStringAsFixed(1),
                ),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _handleHeightChanged,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMaterialDropdown(
    BuildContext context, {
    required String label,
    required AcousticMaterial? value,
    required List<AcousticMaterial> materials,
    required ValueChanged<AcousticMaterial?> onChanged,
  }) {
    return DropdownButtonFormField<AcousticMaterial>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: materials.map((material) {
        return DropdownMenuItem<AcousticMaterial>(
          value: material,
          child: Text(
            material.displayName,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
