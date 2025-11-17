import 'dart:math';
import 'package:common_helpers/common_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'simulation_page_event.dart';
part 'simulation_page_state.dart';

/// Bloc managing the interactive sandbox on the simulation page.
///
/// Handles room dimension changes, palette selections, furniture placement,
/// preset application, and generates synthetic acoustic response metrics used
/// to render the preview charts.
class SimulationPageBloc
    extends Bloc<SimulationPageEvent, SimulationPageState> {
  SimulationPageBloc() : super(SimulationPageState.initial()) {
    on<SimulationRoomDimensionChanged>(_onDimensionChanged);
    on<SimulationFurnitureTypeSelected>(_onFurnitureTypeSelected);
    on<SimulationFurniturePlaced>(_onFurniturePlaced);
    on<SimulationFurnitureRemoved>(_onFurnitureRemoved);
    on<SimulationFurnitureCleared>(_onFurnitureCleared);
    on<SimulationRoomPresetApplied>(_onPresetApplied);
  }

  void _onDimensionChanged(
    SimulationRoomDimensionChanged event,
    Emitter<SimulationPageState> emit,
  ) {
    final updatedState = state.copyWith(
      width: event.width ?? state.width,
      length: event.length ?? state.length,
      height: event.height ?? state.height,
      selectedPresetIndex: -1,
    );
    emit(updatedState.recalculate());
  }

  void _onFurnitureTypeSelected(
    SimulationFurnitureTypeSelected event,
    Emitter<SimulationPageState> emit,
  ) {
    emit(state.copyWith(selectedFurnitureKind: event.kind));
  }

  void _onFurniturePlaced(
    SimulationFurniturePlaced event,
    Emitter<SimulationPageState> emit,
  ) {
    final kind = state.selectedFurnitureKind;
    if (kind == null) {
      return;
    }

    final updatedFurniture = List<SimulationFurnitureItem>.from(
      state.furniture,
    );
    final existingIndex = updatedFurniture.indexWhere(
      (item) => item.gridX == event.gridX && item.gridY == event.gridY,
    );

    if (existingIndex >= 0) {
      updatedFurniture[existingIndex] = updatedFurniture[existingIndex]
          .copyWith(kind: kind, gridX: event.gridX, gridY: event.gridY);
    } else {
      updatedFurniture.add(
        SimulationFurnitureItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          kind: kind,
          gridX: event.gridX,
          gridY: event.gridY,
        ),
      );
    }

    emit(state.copyWith(furniture: updatedFurniture).recalculate());
  }

  void _onFurnitureRemoved(
    SimulationFurnitureRemoved event,
    Emitter<SimulationPageState> emit,
  ) {
    final updatedFurniture = state.furniture
        .where(
          (item) => !(item.gridX == event.gridX && item.gridY == event.gridY),
        )
        .toList(growable: false);
    emit(state.copyWith(furniture: updatedFurniture).recalculate());
  }

  void _onFurnitureCleared(
    SimulationFurnitureCleared event,
    Emitter<SimulationPageState> emit,
  ) {
    emit(
      state
          .copyWith(furniture: const <SimulationFurnitureItem>[])
          .recalculate(),
    );
  }

  void _onPresetApplied(
    SimulationRoomPresetApplied event,
    Emitter<SimulationPageState> emit,
  ) {
    final preset = state.presets[event.index];
    emit(
      state
          .copyWith(
            width: preset.width,
            length: preset.length,
            height: preset.height,
            furniture: preset.templateFurniture,
            selectedPresetIndex: event.index,
          )
          .recalculate(),
    );
  }
}

/// Acoustic utility helpers used by the bloc/state.
class SimulationAcousticMath {
  static List<double> defaultFrequencies() => <double>[
    125,
    250,
    500,
    1000,
    2000,
    4000,
  ];

  static List<double> computeRt60(
    double width,
    double length,
    double height,
    Iterable<SimulationFurnitureItem> furniture,
  ) {
    final volume = width * length * height;
    final surface = 2 * (width * length + width * height + length * height);
    final absorberCount = furniture
        .where((item) => item.kind == SimulationFurnitureKind.absorber)
        .length;
    final diffuserCount = furniture
        .where((item) => item.kind == SimulationFurnitureKind.diffuser)
        .length;

    final baseAbsorption = 0.15 + absorberCount * 0.03 + diffuserCount * 0.01;
    final minAbsorption = 0.1;
    final effectiveAbsorption = max(baseAbsorption, minAbsorption);

    final baseRt = (0.161 * volume) / (surface * effectiveAbsorption);
    final clamped = baseRt.clamp(0.25, 3.2);

    return defaultFrequencies()
        .map((freq) {
          final modifier =
              1.0 - (absorberCount * 0.015) - (diffuserCount * 0.008);
          final freqShape =
              1 +
              (freq >= 2000
                  ? -0.08
                  : freq >= 1000
                  ? -0.04
                  : 0.06);
          final value = clamped * modifier * freqShape;
          return value.clamp(0.2, 2.6);
        })
        .toList(growable: false);
  }

  static List<double> computeSti(
    double width,
    double length,
    double height,
    Iterable<SimulationFurnitureItem> furniture,
  ) {
    final seating = furniture
        .where((item) => item.kind == SimulationFurnitureKind.seating)
        .length;
    final absorbers = furniture
        .where((item) => item.kind == SimulationFurnitureKind.absorber)
        .length;
    final diffusers = furniture
        .where((item) => item.kind == SimulationFurnitureKind.diffuser)
        .length;

    final baseline =
        0.42 + (seating * 0.01) + (absorbers * 0.012) + (diffusers * 0.006);
    final volume = width * length * height;
    final volumeFactor = (volume / 200).clamp(0.0, 0.15);

    return defaultFrequencies()
        .map((freq) {
          final freqWeight = freq >= 2000
              ? 0.14
              : freq >= 1000
              ? 0.1
              : 0.06;
          final value = (baseline + freqWeight - volumeFactor)
              .clamp(0.3, 0.95)
              .toDouble();
          return roundToDigits(value, fractionDigits: 3);
        })
        .toList(growable: false);
  }

  static List<double> computeD50(
    double width,
    double length,
    double height,
    Iterable<SimulationFurnitureItem> furniture,
  ) {
    final diffusers = furniture
        .where((item) => item.kind == SimulationFurnitureKind.diffuser)
        .length;
    final stage = furniture
        .where((item) => item.kind == SimulationFurnitureKind.stage)
        .length;

    final base = 0.38 + diffusers * 0.015 + stage * 0.008;
    final enclosureFactor = ((width + length) / 40).clamp(0.0, 0.12);

    return defaultFrequencies()
        .map((freq) {
          final freqWeight = freq >= 2000
              ? 0.18
              : freq >= 1000
              ? 0.12
              : 0.06;
          final value = (base + freqWeight + enclosureFactor)
              .clamp(0.35, 0.95)
              .toDouble();
          return roundToDigits(value, fractionDigits: 3);
        })
        .toList(growable: false);
  }
}
