import 'package:backend_gateway/backend_gateway.dart';
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
  SimulationPageBloc({SimulationReferenceRepository? referenceRepository})
    : _referenceRepository = referenceRepository,
      super(SimulationPageState.initial()) {
    on<SimulationRoomDimensionChanged>(_onDimensionChanged);
    on<SimulationFurnitureTypeSelected>(_onFurnitureTypeSelected);
    on<SimulationFurniturePlaced>(_onFurniturePlaced);
    on<SimulationFurnitureRemoved>(_onFurnitureRemoved);
    on<SimulationFurnitureCleared>(_onFurnitureCleared);
    on<SimulationRoomPresetApplied>(_onPresetApplied);
    on<SimulationTimelineAdvanced>(_onTimelineAdvanced);
    on<SimulationTimelineStepBack>(_onTimelineStepBack);
    on<SimulationResultReceived>(_onResultReceived);
    on<SimulationReferenceProfilesRequested>(_onReferenceProfilesRequested);
  }

  final SimulationReferenceRepository? _referenceRepository;

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

  void _onTimelineAdvanced(
    SimulationTimelineAdvanced event,
    Emitter<SimulationPageState> emit,
  ) {
    final nextIndex = (state.activeStepIndex + 1) % state.steps.length;
    emit(state.copyWith(activeStepIndex: nextIndex));
  }

  void _onTimelineStepBack(
    SimulationTimelineStepBack event,
    Emitter<SimulationPageState> emit,
  ) {
    if (state.activeStepIndex > 0) {
      emit(state.copyWith(activeStepIndex: state.activeStepIndex - 1));
    }
  }

  void _onResultReceived(
    SimulationResultReceived event,
    Emitter<SimulationPageState> emit,
  ) {
    final result = SimulationResult.tryParse(event.payload);
    if (result == null) {
      debugPrint('Simulation result parsing failed; payload ignored.');
      return;
    }
    if (event.isRaytracing) {
      emit(state.copyWith(lastRaytracingResult: result));
    } else {
      emit(state.copyWith(lastResult: result));
    }
  }

  Future<void> _onReferenceProfilesRequested(
    SimulationReferenceProfilesRequested event,
    Emitter<SimulationPageState> emit,
  ) async {
    final repository = _referenceRepository;
    if (repository == null) {
      emit(
        state.copyWith(
          referenceProfilesStatus: SimulationReferenceProfilesStatus.failure,
          referenceProfilesError: 'Reference repository unavailable',
        ),
      );
      return;
    }

    if (state.referenceProfilesStatus ==
        SimulationReferenceProfilesStatus.loading) {
      return;
    }

    emit(
      state.copyWith(
        referenceProfilesStatus: SimulationReferenceProfilesStatus.loading,
        referenceProfilesError: null,
      ),
    );

    try {
      final dtos = await repository.fetchReferenceProfiles();
      final profiles = dtos
          .map((dto) {
            final metrics = dto.metrics
                .where((metric) => metric.value != null)
                .map(
                  (metric) => SimulationReferenceMetric(
                    key: metric.key,
                    label: metric.label,
                    value: metric.value!,
                    unit: metric.unit,
                    minValue: metric.minValue,
                    maxValue: metric.maxValue,
                  ),
                )
                .toList(growable: false);

            return SimulationReferenceProfile(
              id: dto.id,
              displayName: dto.displayName,
              notes: dto.notes,
              metrics: metrics,
            );
          })
          .where((profile) => profile.metrics.isNotEmpty)
          .toList(growable: false);

      emit(
        state.copyWith(
          referenceProfiles: profiles,
          referenceProfilesStatus: SimulationReferenceProfilesStatus.success,
          referenceProfilesError: null,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Reference profile fetch failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'SimulationPageBloc',
        ),
      );
      emit(
        state.copyWith(
          referenceProfilesStatus: SimulationReferenceProfilesStatus.failure,
          referenceProfilesError: error.toString(),
        ),
      );
    }
  }
}
