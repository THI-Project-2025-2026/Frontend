part of 'simulation_page_bloc.dart';

const Object _copyWithUnset = Object();

/// High level categories of furniture or treatment elements that can be placed
/// into the simulation grid.
enum SimulationFurnitureKind { absorber, diffuser, seating, stage }

/// Metadata for the simulation step timeline.
class SimulationStepDescriptor {
  const SimulationStepDescriptor({
    required this.index,
    required this.titleKey,
    required this.descriptionKey,
    this.fallbackTitle,
    this.fallbackDescription,
  });

  final int index;
  final String titleKey;
  final String descriptionKey;
  final String? fallbackTitle;
  final String? fallbackDescription;
}

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

enum SimulationReferenceProfilesStatus { initial, loading, success, failure }

class SimulationReferenceMetric {
  const SimulationReferenceMetric({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.minValue,
    this.maxValue,
  });

  final String key;
  final String label;
  final double value;
  final String? unit;
  final double? minValue;
  final double? maxValue;
}

/// Reference profile definition supplied by the backend service.
class SimulationReferenceProfile {
  SimulationReferenceProfile({
    required this.id,
    required this.displayName,
    required List<SimulationReferenceMetric> metrics,
    this.notes,
  }) : metrics = List.unmodifiable(metrics);

  final String id;
  final String displayName;
  final List<SimulationReferenceMetric> metrics;
  final String? notes;
}

/// Captures the parsed response from the backend simulation service.
class SimulationResult {
  SimulationResult({
    required this.sampleRateHz,
    required List<SimulationResultPair> pairs,
    required List<String> warnings,
  }) : pairs = List.unmodifiable(pairs),
       warnings = List.unmodifiable(warnings);

  final int sampleRateHz;
  final List<SimulationResultPair> pairs;
  final List<String> warnings;

  static SimulationResult? tryParse(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final sampleRate = _asInt(json['sample_rate_hz']);
    final pairsRaw = json['pairs'];
    if (sampleRate == null || pairsRaw is! List) {
      return null;
    }
    final parsedPairs = <SimulationResultPair>[];
    for (final rawPair in pairsRaw) {
      final pair = SimulationResultPair.tryParse(rawPair);
      if (pair != null) {
        parsedPairs.add(pair);
      }
    }

    return SimulationResult(
      sampleRateHz: sampleRate,
      pairs: parsedPairs,
      warnings: _stringList(json['warnings']),
    );
  }
}

class SimulationResultPair {
  SimulationResultPair({
    required this.sourceId,
    required this.microphoneId,
    required this.metrics,
    required List<String> warnings,
  }) : warnings = List.unmodifiable(warnings);

  final String sourceId;
  final String microphoneId;
  final SimulationResultMetrics metrics;
  final List<String> warnings;

  static SimulationResultPair? tryParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final sourceId = raw['source_id'] as String?;
    final microphoneId = raw['microphone_id'] as String?;
    if (sourceId == null || microphoneId == null) {
      return null;
    }
    final metrics = SimulationResultMetrics.fromJson(
      raw['metrics'] as Map<String, dynamic>?,
    );
    return SimulationResultPair(
      sourceId: sourceId,
      microphoneId: microphoneId,
      metrics: metrics,
      warnings: _stringList(raw['warnings']),
    );
  }
}

class SimulationResultMetrics {
  SimulationResultMetrics({
    required Map<String, double?> values,
    this.stiMethod,
  }) : values = Map.unmodifiable(values);

  final Map<String, double?> values;
  final String? stiMethod;

  double? operator [](String key) => values[key];

  static SimulationResultMetrics fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SimulationResultMetrics(values: const {});
    }

    final extracted = <String, double?>{};
    String? method;
    json.forEach((key, rawValue) {
      if (key == 'sti_method') {
        method = rawValue as String?;
        return;
      }
      final parsed = _asDouble(rawValue);
      if (parsed != null) {
        extracted[key] = parsed;
      }
    });

    return SimulationResultMetrics(values: extracted, stiMethod: method);
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

@immutable
class SimulationPageState {
  SimulationPageState({
    required this.width,
    required this.length,
    required this.height,
    required List<SimulationFurnitureItem> furniture,
    required this.selectedFurnitureKind,
    required List<SimulationRoomPreset> presets,
    required this.selectedPresetIndex,
    required List<SimulationFurnitureDescriptor> palette,
    required List<SimulationStepDescriptor> steps,
    required this.activeStepIndex,
    required this.lastResult,
    required this.lastRaytracingResult,
    required List<SimulationReferenceProfile> referenceProfiles,
    required this.referenceProfilesStatus,
    required this.referenceProfilesError,
  }) : furniture = List.unmodifiable(furniture),
       presets = List.unmodifiable(presets),
       palette = List.unmodifiable(palette),
       steps = List.unmodifiable(steps),
       referenceProfiles = List.unmodifiable(referenceProfiles);

  static const int gridSize = 8;

  final double width;
  final double length;
  final double height;
  final List<SimulationFurnitureItem> furniture;
  final SimulationFurnitureKind? selectedFurnitureKind;
  final List<SimulationRoomPreset> presets;
  final int selectedPresetIndex;
  final List<SimulationFurnitureDescriptor> palette;
  final List<SimulationStepDescriptor> steps;
  final int activeStepIndex;
  final SimulationResult? lastResult;
  final SimulationResult? lastRaytracingResult;
  final List<SimulationReferenceProfile> referenceProfiles;
  final SimulationReferenceProfilesStatus referenceProfilesStatus;
  final String? referenceProfilesError;

  SimulationStepDescriptor? get activeStep {
    if (steps.isEmpty) {
      return null;
    }
    final index = activeStepIndex.clamp(0, steps.length - 1);
    return steps[index];
  }

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
    List<SimulationRoomPreset>? presets,
    int? selectedPresetIndex,
    List<SimulationFurnitureDescriptor>? palette,
    List<SimulationStepDescriptor>? steps,
    int? activeStepIndex,
    Object? lastResult = _copyWithUnset,
    Object? lastRaytracingResult = _copyWithUnset,
    List<SimulationReferenceProfile>? referenceProfiles,
    SimulationReferenceProfilesStatus? referenceProfilesStatus,
    Object? referenceProfilesError = _copyWithUnset,
  }) {
    return SimulationPageState(
      width: width ?? this.width,
      length: length ?? this.length,
      height: height ?? this.height,
      furniture: furniture ?? this.furniture,
      selectedFurnitureKind:
          selectedFurnitureKind ?? this.selectedFurnitureKind,
      presets: presets ?? this.presets,
      selectedPresetIndex: selectedPresetIndex ?? this.selectedPresetIndex,
      palette: palette ?? this.palette,
      steps: steps ?? this.steps,
      activeStepIndex: activeStepIndex ?? this.activeStepIndex,
      lastResult: identical(lastResult, _copyWithUnset)
          ? this.lastResult
          : lastResult as SimulationResult?,
      lastRaytracingResult: identical(lastRaytracingResult, _copyWithUnset)
          ? this.lastRaytracingResult
          : lastRaytracingResult as SimulationResult?,
      referenceProfiles: referenceProfiles ?? this.referenceProfiles,
      referenceProfilesStatus:
          referenceProfilesStatus ?? this.referenceProfilesStatus,
      referenceProfilesError: identical(referenceProfilesError, _copyWithUnset)
          ? this.referenceProfilesError
          : referenceProfilesError as String?,
    );
  }

  SimulationPageState recalculate() => this;

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

    const steps = <SimulationStepDescriptor>[
      SimulationStepDescriptor(
        index: 0,
        titleKey: 'simulation_page.timeline.steps.0.title',
        descriptionKey: 'simulation_page.timeline.steps.0.description',
      ),
      SimulationStepDescriptor(
        index: 1,
        titleKey: 'simulation_page.timeline.steps.1.title',
        descriptionKey: 'simulation_page.timeline.steps.1.description',
      ),
      SimulationStepDescriptor(
        index: 2,
        titleKey: 'simulation_page.timeline.steps.devices.title',
        descriptionKey: 'simulation_page.timeline.steps.devices.description',
        fallbackTitle: 'Place speakers and microphones',
        fallbackDescription:
            'Add at least one speaker and one microphone before running the simulation.',
      ),
      SimulationStepDescriptor(
        index: 3,
        titleKey: 'simulation_page.timeline.steps.2.title',
        descriptionKey: 'simulation_page.timeline.steps.2.description',
      ),
      SimulationStepDescriptor(
        index: 4,
        titleKey: 'simulation_page.timeline.steps.3.title',
        descriptionKey: 'simulation_page.timeline.steps.3.description',
      ),
    ];

    final state = SimulationPageState(
      width: presets.first.width,
      length: presets.first.length,
      height: presets.first.height,
      furniture: const <SimulationFurnitureItem>[],
      selectedFurnitureKind: SimulationFurnitureKind.absorber,
      presets: presets,
      selectedPresetIndex: 0,
      palette: palette,
      steps: steps,
      activeStepIndex: 0,
      lastResult: null,
      lastRaytracingResult: null,
      referenceProfiles: const <SimulationReferenceProfile>[],
      referenceProfilesStatus: SimulationReferenceProfilesStatus.initial,
      referenceProfilesError: null,
    );

    return state.recalculate();
  }
}
