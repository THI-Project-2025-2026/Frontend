part of 'simulation_page_bloc.dart';

/// High level categories of furniture or treatment elements that can be placed
/// into the simulation grid.
enum SimulationFurnitureKind { absorber, diffuser, seating, stage }

/// Describes metadata for palette entries.
class SimulationFurnitureDescriptor {
  const SimulationFurnitureDescriptor({
    required this.kind,
    required this.labelKey,
    required this.icon,
    required this.colorKey,
  });

  final SimulationFurnitureKind kind;
  final String labelKey;
  final IconData icon;
  final String colorKey;
}

/// Predefined room presets exposed in the UI.
class SimulationRoomPreset {
  const SimulationRoomPreset({
    required this.labelKey,
    required this.descriptionKey,
    required this.width,
    required this.length,
    required this.height,
    this.templateFurniture = const <SimulationFurnitureItem>[],
  });

  final String labelKey;
  final String descriptionKey;
  final double width;
  final double length;
  final double height;
  final List<SimulationFurnitureItem> templateFurniture;
}

/// Single piece of placed furniture within the grid.
class SimulationFurnitureItem {
  const SimulationFurnitureItem({
    required this.id,
    required this.kind,
    required this.gridX,
    required this.gridY,
  });

  final String id;
  final SimulationFurnitureKind kind;
  final int gridX;
  final int gridY;

  SimulationFurnitureItem copyWith({
    String? id,
    SimulationFurnitureKind? kind,
    int? gridX,
    int? gridY,
  }) {
    return SimulationFurnitureItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
    );
  }
}

/// Acoustic metric series powering line charts.
class SimulationMetricSeries {
  SimulationMetricSeries({
    required this.labelKey,
    required this.unitKey,
    required this.colorKey,
    required List<double> frequencies,
    required List<double> values,
  }) : frequencies = List.unmodifiable(frequencies),
       values = List.unmodifiable(values);

  final String labelKey;
  final String unitKey;
  final String colorKey;
  final List<double> frequencies;
  final List<double> values;
}

@immutable
class SimulationPageState {
  SimulationPageState({
    required this.width,
    required this.length,
    required this.height,
    required List<SimulationFurnitureItem> furniture,
    required this.selectedFurnitureKind,
    required List<SimulationMetricSeries> metrics,
    required List<SimulationRoomPreset> presets,
    required this.selectedPresetIndex,
    required List<SimulationFurnitureDescriptor> palette,
  }) : furniture = List.unmodifiable(furniture),
       metrics = List.unmodifiable(metrics),
       presets = List.unmodifiable(presets),
       palette = List.unmodifiable(palette);

  static const int gridSize = 8;

  final double width;
  final double length;
  final double height;
  final List<SimulationFurnitureItem> furniture;
  final SimulationFurnitureKind? selectedFurnitureKind;
  final List<SimulationMetricSeries> metrics;
  final List<SimulationRoomPreset> presets;
  final int selectedPresetIndex;
  final List<SimulationFurnitureDescriptor> palette;

  SimulationFurnitureItem? furnitureAt(int x, int y) {
    for (final item in furniture) {
      if (item.gridX == x && item.gridY == y) {
        return item;
      }
    }
    return null;
  }

  SimulationPageState copyWith({
    double? width,
    double? length,
    double? height,
    List<SimulationFurnitureItem>? furniture,
    SimulationFurnitureKind? selectedFurnitureKind,
    List<SimulationMetricSeries>? metrics,
    List<SimulationRoomPreset>? presets,
    int? selectedPresetIndex,
    List<SimulationFurnitureDescriptor>? palette,
  }) {
    return SimulationPageState(
      width: width ?? this.width,
      length: length ?? this.length,
      height: height ?? this.height,
      furniture: furniture ?? this.furniture,
      selectedFurnitureKind:
          selectedFurnitureKind ?? this.selectedFurnitureKind,
      metrics: metrics ?? this.metrics,
      presets: presets ?? this.presets,
      selectedPresetIndex: selectedPresetIndex ?? this.selectedPresetIndex,
      palette: palette ?? this.palette,
    );
  }

  SimulationPageState recalculate() {
    final rt60 = SimulationAcousticMath.computeRt60(
      width,
      length,
      height,
      furniture,
    );
    final sti = SimulationAcousticMath.computeSti(
      width,
      length,
      height,
      furniture,
    );
    final d50 = SimulationAcousticMath.computeD50(
      width,
      length,
      height,
      furniture,
    );

    final frequencies = SimulationAcousticMath.defaultFrequencies();

    return copyWith(
      metrics: <SimulationMetricSeries>[
        SimulationMetricSeries(
          labelKey: 'simulation_page.metrics.rt60.label',
          unitKey: 'simulation_page.metrics.rt60.unit',
          colorKey: 'simulation_page.graphs.rt60_line',
          frequencies: frequencies,
          values: rt60,
        ),
        SimulationMetricSeries(
          labelKey: 'simulation_page.metrics.sti.label',
          unitKey: 'simulation_page.metrics.sti.unit',
          colorKey: 'simulation_page.graphs.sti_line',
          frequencies: frequencies,
          values: sti,
        ),
        SimulationMetricSeries(
          labelKey: 'simulation_page.metrics.d50.label',
          unitKey: 'simulation_page.metrics.d50.unit',
          colorKey: 'simulation_page.graphs.d50_line',
          frequencies: frequencies,
          values: d50,
        ),
      ],
    );
  }

  static SimulationPageState initial() {
    const presets = <SimulationRoomPreset>[
      SimulationRoomPreset(
        labelKey: 'simulation_page.presets.items.0.label',
        descriptionKey: 'simulation_page.presets.items.0.description',
        width: 6.5,
        length: 9.0,
        height: 3.2,
      ),
      SimulationRoomPreset(
        labelKey: 'simulation_page.presets.items.1.label',
        descriptionKey: 'simulation_page.presets.items.1.description',
        width: 12.0,
        length: 18.0,
        height: 6.0,
      ),
      SimulationRoomPreset(
        labelKey: 'simulation_page.presets.items.2.label',
        descriptionKey: 'simulation_page.presets.items.2.description',
        width: 8.0,
        length: 12.0,
        height: 4.0,
      ),
    ];

    const palette = <SimulationFurnitureDescriptor>[
      SimulationFurnitureDescriptor(
        kind: SimulationFurnitureKind.absorber,
        labelKey: 'simulation_page.palette.absorber',
        icon: Icons.blur_on,
        colorKey: 'simulation_page.furniture.absorber',
      ),
      SimulationFurnitureDescriptor(
        kind: SimulationFurnitureKind.diffuser,
        labelKey: 'simulation_page.palette.diffuser',
        icon: Icons.scatter_plot,
        colorKey: 'simulation_page.furniture.diffuser',
      ),
      SimulationFurnitureDescriptor(
        kind: SimulationFurnitureKind.seating,
        labelKey: 'simulation_page.palette.seating',
        icon: Icons.event_seat,
        colorKey: 'simulation_page.furniture.seating',
      ),
      SimulationFurnitureDescriptor(
        kind: SimulationFurnitureKind.stage,
        labelKey: 'simulation_page.palette.stage',
        icon: Icons.crop_square,
        colorKey: 'simulation_page.furniture.stage',
      ),
    ];

    final state = SimulationPageState(
      width: presets.first.width,
      length: presets.first.length,
      height: presets.first.height,
      furniture: const <SimulationFurnitureItem>[],
      selectedFurnitureKind: SimulationFurnitureKind.absorber,
      metrics: const <SimulationMetricSeries>[],
      presets: presets,
      selectedPresetIndex: 0,
      palette: palette,
    );

    return state.recalculate();
  }
}
