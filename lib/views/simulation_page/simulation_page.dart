import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sonalyze_frontend/blocs/simulation_page/simulation_page_bloc.dart';
import 'package:sonalyze_frontend/constants/app_constants.dart';
import 'package:sonalyze_frontend/utilities/ui/common/sonalyze_button.dart';
import 'package:sonalyze_frontend/utilities/ui/common/sonalyze_surface.dart';
import 'package:sonalyze_frontend/services/room_creation/room_creation_loader.dart';

class SimulationPageScreen extends StatelessWidget {
  const SimulationPageScreen({super.key});

  static const String routeName = '/simulation';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SimulationPageBloc(),
      child: const _SimulationPageView(),
    );
  }
}

class _SimulationPageView extends StatelessWidget {
  const _SimulationPageView();

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = _themeColors(
      'simulation_page.background_gradient',
    );

    return Scaffold(
      backgroundColor: _themeColor('app.background'),
      body: Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient.length >= 2
              ? LinearGradient(
                  colors: backgroundGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: backgroundGradient.isEmpty
              ? _themeColor('app.background')
              : null,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1280;
              final isMedium = constraints.maxWidth >= 980;
              final contentPadding = EdgeInsets.symmetric(
                horizontal: isWide
                    ? 96
                    : isMedium
                    ? 64
                    : 24,
                vertical: isWide ? 48 : 32,
              );

              return ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all<Color>(
                    _themeColor(
                      'simulation_page.scrollbar_thumb',
                    ).withValues(alpha: 0.75),
                  ),
                  thickness: const WidgetStatePropertyAll<double>(6),
                  radius: const Radius.circular(999),
                ),
                child: SingleChildScrollView(
                  padding: contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SimulationHeader(),
                      SizedBox(height: isWide ? 40 : 32),
                      _SimulationPrimaryLayout(
                        isWide: isWide,
                        isMedium: isMedium,
                      ),
                      SizedBox(height: isWide ? 48 : 36),
                      const _RoomCreationSection(),
                      SizedBox(height: isWide ? 48 : 36),
                      const _SimulationMetricSection(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SimulationHeader extends StatelessWidget {
  const _SimulationHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeColor = _themeColor('simulation_page.header_badge_background');
    final badgeText = _themeColor('simulation_page.header_badge_text');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _tr('simulation_page.badge'),
            style: textTheme.labelLarge?.copyWith(
              color: badgeText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _tr('simulation_page.title'),
          style: textTheme.displaySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _tr('simulation_page.subtitle'),
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

class _SimulationPrimaryLayout extends StatelessWidget {
  const _SimulationPrimaryLayout({
    required this.isWide,
    required this.isMedium,
  });

  final bool isWide;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimulationPageBloc, SimulationPageState>(
      builder: (context, state) {
        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: _SimulationConfigurator(
                    state: state,
                    expandToHeight: true,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: _SimulationGridCard(
                      state: state,
                      expandToHeight: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (isMedium) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SimulationConfigurator(
                        state: state,
                        expandToHeight: true,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _SimulationGridCard(
                        state: state,
                        expandToHeight: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _SimulationConfigurator(state: state),
            const SizedBox(height: 24),
            _SimulationGridCard(state: state),
          ],
        );
      },
    );
  }
}

class _RoomCreationSection extends StatefulWidget {
  const _RoomCreationSection();

  @override
  State<_RoomCreationSection> createState() => _RoomCreationSectionState();
}

class _RoomCreationSectionState extends State<_RoomCreationSection> {
  final RoomCreationController _controller = RoomCreationController();
  String _lastMessage = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final surfaceColor = _themeColor('simulation_page.panel_background');
    final onSurface = theme.colorScheme.onSurface;
    final helperColor = onSurface.withValues(alpha: 0.7);
    final brightness = theme.brightness;
    final title = _tr('simulation_page.room_creator.title');
    final description = _tr('simulation_page.room_creator.description');
    final lastPrefix = _tr('simulation_page.room_creator.last_message_prefix');
    final lastPlaceholder = _tr(
      'simulation_page.room_creator.last_message_placeholder',
    );
    final sendLabel = _tr('simulation_page.room_creator.send_demo');
    final demoPayload = _tr('simulation_page.room_creator.demo_message');
    final mode = brightness == Brightness.dark
        ? RoomCreationThemeMode.dark
        : RoomCreationThemeMode.light;

    final lastLabel = _lastMessage.isEmpty
        ? '$lastPrefix$lastPlaceholder'
        : '$lastPrefix$_lastMessage';

    return SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: helperColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 440,
              width: double.infinity,
              child: RoomCreationView(
                controller: _controller,
                themeMode: mode,
                onMessage: (message) {
                  setState(() {
                    _lastMessage = message;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  lastLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: helperColor),
                ),
              ),
              const SizedBox(width: 16),
              SonalyzeButton(
                onPressed: () {
                  _controller.sendMessage(demoPayload);
                },
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(
                  sendLabel,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimulationConfigurator extends StatelessWidget {
  const _SimulationConfigurator({
    required this.state,
    this.expandToHeight = false,
  });

  final SimulationPageState state;
  final bool expandToHeight;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.panel_background');
    final sectionSpacing = SizedBox(height: 28);

    final content = SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfiguratorSectionTitle(
            title: _tr('simulation_page.presets.title'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < state.presets.length; i++)
                _PresetChip(index: i, state: state),
            ],
          ),
          sectionSpacing,
          _ConfiguratorSectionTitle(
            title: _tr('simulation_page.dimensions.title'),
          ),
          const SizedBox(height: 16),
          _DimensionSlider(
            label: _tr('simulation_page.dimensions.width'),
            value: state.width,
            onChanged: (value) => context.read<SimulationPageBloc>().add(
              SimulationRoomDimensionChanged(width: value),
            ),
          ),
          const SizedBox(height: 16),
          _DimensionSlider(
            label: _tr('simulation_page.dimensions.length'),
            value: state.length,
            onChanged: (value) => context.read<SimulationPageBloc>().add(
              SimulationRoomDimensionChanged(length: value),
            ),
          ),
          const SizedBox(height: 16),
          _DimensionSlider(
            label: _tr('simulation_page.dimensions.height'),
            value: state.height,
            max: 9,
            min: 2.5,
            onChanged: (value) => context.read<SimulationPageBloc>().add(
              SimulationRoomDimensionChanged(height: value),
            ),
          ),
          sectionSpacing,
          _ConfiguratorSectionTitle(
            title: _tr('simulation_page.palette.title'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final descriptor in state.palette)
                _FurnitureChip(
                  descriptor: descriptor,
                  selected: state.selectedFurnitureKind == descriptor.kind,
                ),
              _ClearLayoutButton(
                onPressed: () {
                  context.read<SimulationPageBloc>().add(
                    const SimulationFurnitureCleared(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );

    if (!expandToHeight) {
      return content;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [Expanded(child: content)],
    );
  }
}

class _ConfiguratorSectionTitle extends StatelessWidget {
  const _ConfiguratorSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.index, required this.state});

  final int index;
  final SimulationPageState state;

  @override
  Widget build(BuildContext context) {
    final preset = state.presets[index];
    final selected = state.selectedPresetIndex == index;
    final selectedColor = _themeColor(
      'simulation_page.palette.chip_selected_bg',
    );
    final selectedText = _themeColor(
      'simulation_page.palette.chip_selected_text',
    );
    final unselectedBorder = _themeColor('simulation_page.panel_border');

    return ChoiceChip(
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_tr(preset.labelKey)),
          const SizedBox(height: 4),
          Text(
            _tr(preset.descriptionKey),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      selected: selected,
      onSelected: (_) => context.read<SimulationPageBloc>().add(
        SimulationRoomPresetApplied(index: index),
      ),
      selectedColor: selectedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : unselectedBorder.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected
            ? selectedText
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DimensionSlider extends StatelessWidget {
  const _DimensionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 3,
    this.max = 24,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final sliderColor = _themeColor('simulation_page.slider_active');
    final inactive = sliderColor.withValues(alpha: 0.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)} ${_tr('simulation_page.dimensions.unit')}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: sliderColor,
            inactiveTrackColor: inactive,
            thumbColor: sliderColor,
            overlayColor: sliderColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            min: min,
            max: max,
            divisions: ((max - min) * 2).round(),
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _FurnitureChip extends StatelessWidget {
  const _FurnitureChip({required this.descriptor, required this.selected});

  final SimulationFurnitureDescriptor descriptor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final selectedBg = _themeColor('simulation_page.palette.chip_selected_bg');
    final selectedText = _themeColor(
      'simulation_page.palette.chip_selected_text',
    );
    final unselectedBg = _themeColor(
      'simulation_page.palette.chip_unselected_bg',
    );
    final unselectedText = _themeColor(
      'simulation_page.palette.chip_unselected_text',
    );

    return GestureDetector(
      onTap: () {
        context.read<SimulationPageBloc>().add(
          SimulationFurnitureTypeSelected(descriptor.kind),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? selectedBg.withValues(alpha: 0.3)
                : unselectedBg.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              descriptor.icon,
              size: 20,
              color: selected ? selectedText : unselectedText,
            ),
            const SizedBox(width: 10),
            Text(
              _tr(descriptor.labelKey),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? selectedText : unselectedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearLayoutButton extends StatelessWidget {
  const _ClearLayoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final destructive = _themeColor('simulation_page.palette.clear_text');

    return SonalyzeButton(
      onPressed: onPressed,
      variant: SonalyzeButtonVariant.text,
      foregroundColor: destructive,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      icon: Icon(Icons.delete_sweep_outlined, color: destructive),
      child: Text(
        _tr('simulation_page.palette.clear'),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: destructive,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SimulationGridCard extends StatelessWidget {
  const _SimulationGridCard({required this.state, this.expandToHeight = false});

  final SimulationPageState state;
  final bool expandToHeight;

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.grid_background');
    final helperColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);

    final content = SonalyzeSurface(
      padding: const EdgeInsets.all(28),
      backgroundColor: panelColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('simulation_page.grid.title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tr('simulation_page.grid.helper'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: helperColor, height: 1.5),
          ),
          const SizedBox(height: 20),
          _SimulationGridCanvas(state: state),
          const SizedBox(height: 20),
          _SimulationLegend(state: state),
        ],
      ),
    );

    if (!expandToHeight) {
      return content;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [Expanded(child: content)],
    );
  }
}

class _SimulationGridCanvas extends StatelessWidget {
  const _SimulationGridCanvas({required this.state});

  final SimulationPageState state;

  @override
  Widget build(BuildContext context) {
    final gridLines = _themeColor('simulation_page.grid_line');
    final selectedBorder = _themeColor('simulation_page.grid_cell_active');
    final highlight = _themeColor('simulation_page.grid_cell_hover');

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / SimulationPageState.gridSize;
          return GestureDetector(
            onTapDown: (details) {
              final local = details.localPosition;
              final gridX = (local.dx / cellSize).floor().clamp(
                0,
                SimulationPageState.gridSize - 1,
              );
              final gridY = (local.dy / cellSize).floor().clamp(
                0,
                SimulationPageState.gridSize - 1,
              );
              final existing = state.furnitureAt(gridX, gridY);

              if (existing != null &&
                  state.selectedFurnitureKind == existing.kind) {
                context.read<SimulationPageBloc>().add(
                  SimulationFurnitureRemoved(gridX: gridX, gridY: gridY),
                );
              } else if (state.selectedFurnitureKind == null &&
                  existing != null) {
                context.read<SimulationPageBloc>().add(
                  SimulationFurnitureRemoved(gridX: gridX, gridY: gridY),
                );
              } else {
                context.read<SimulationPageBloc>().add(
                  SimulationFurniturePlaced(gridX: gridX, gridY: gridY),
                );
              }
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.square(constraints.maxWidth),
                  painter: _GridPainter(
                    gridColor: gridLines.withValues(alpha: 0.35),
                  ),
                ),
                for (final item in state.furniture)
                  Positioned(
                    left: item.gridX * cellSize,
                    top: item.gridY * cellSize,
                    width: cellSize,
                    height: cellSize,
                    child: _GridCellFurniture(
                      item: item,
                      borderColor: selectedBorder,
                      highlight: highlight,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final cell = size.width / SimulationPageState.gridSize;
    for (var i = 0; i <= SimulationPageState.gridSize; i++) {
      final offset = i * cell;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), paint);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridCellFurniture extends StatelessWidget {
  const _GridCellFurniture({
    required this.item,
    required this.borderColor,
    required this.highlight,
  });

  final SimulationFurnitureItem item;
  final Color borderColor;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final colorKey = 'simulation_page.furniture.${item.kind.name}';
    final fill = _themeColor(colorKey);
    final icon = _iconFor(item.kind);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: highlight.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SimulationFurnitureKind kind) {
    switch (kind) {
      case SimulationFurnitureKind.absorber:
        return Icons.blur_on;
      case SimulationFurnitureKind.diffuser:
        return Icons.scatter_plot;
      case SimulationFurnitureKind.seating:
        return Icons.event_seat;
      case SimulationFurnitureKind.stage:
        return Icons.view_day;
    }
  }
}

class _SimulationLegend extends StatelessWidget {
  const _SimulationLegend({required this.state});

  final SimulationPageState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.palette;

    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: [
        for (final descriptor in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _themeColor(descriptor.colorKey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _tr('simulation_page.grid.legend.${descriptor.kind.name}'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SimulationMetricSection extends StatelessWidget {
  const _SimulationMetricSection();

  @override
  Widget build(BuildContext context) {
    final panelColor = _themeColor('simulation_page.metrics_background');

    return BlocBuilder<SimulationPageBloc, SimulationPageState>(
      builder: (context, state) {
        return SonalyzeSurface(
          padding: const EdgeInsets.all(28),
          backgroundColor: panelColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('simulation_page.metrics.title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 1000;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - 32) / 3
                      : double.infinity;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final series in state.metrics)
                        SizedBox(
                          width: itemWidth,
                          child: _MetricChartCard(series: series),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricChartCard extends StatelessWidget {
  const _MetricChartCard({required this.series});

  final SimulationMetricSeries series;

  @override
  Widget build(BuildContext context) {
    final cardColor = _themeColor('simulation_page.graphs.card_background');
    final axisColor = _themeColor('simulation_page.graphs.axis');
    final lineColor = _themeColor(series.colorKey);
    final fillColor = _themeColor('${series.colorKey}_fill');

    final latestValue = series.values.last;

    return SonalyzeSurface(
      padding: const EdgeInsets.all(20),
      backgroundColor: cardColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(series.labelKey),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${latestValue.toStringAsFixed(2)} ${_tr(series.unitKey)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _MetricChartPainter(
                series: series,
                axisColor: axisColor.withValues(alpha: 0.4),
                lineColor: lineColor,
                fillColor: fillColor.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({
    required this.series,
    required this.axisColor,
    required this.lineColor,
    required this.fillColor,
  });

  final SimulationMetricSeries series;
  final Color axisColor;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final origin = Offset(padding, size.height - padding);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    canvas.drawLine(
      origin,
      Offset(origin.dx + chartWidth, origin.dy),
      axisPaint,
    );
    canvas.drawLine(
      origin,
      Offset(origin.dx, origin.dy - chartHeight),
      axisPaint,
    );

    final maxValue = series.values.reduce((a, b) => a > b ? a : b);
    final minValue = series.values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs() < 0.001
        ? 1
        : (maxValue - minValue);

    final points = <Offset>[];
    for (var i = 0; i < series.values.length; i++) {
      final progress = i / (series.values.length - 1);
      final x = origin.dx + chartWidth * progress;
      final normalized = (series.values[i] - minValue) / span;
      final y = origin.dy - normalized * chartHeight;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, origin.dy);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, origin.dy);
    fillPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

String _tr(String keyPath) {
  final value = AppConstants.translation(keyPath);
  if (value is String) {
    return value;
  }
  return '';
}

Color _themeColor(String keyPath) {
  return AppConstants.getThemeColor(keyPath);
}

List<Color> _themeColors(String keyPath) {
  return AppConstants.getThemeColors(keyPath);
}
