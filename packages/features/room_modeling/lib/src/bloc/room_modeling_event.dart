import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'room_modeling_state.dart'
    show RoomModelingTool, RoomModelingStep, AcousticMaterial;
import '../storage/room_plan_importer.dart';

abstract class RoomModelingEvent extends Equatable {
  const RoomModelingEvent();

  @override
  List<Object?> get props => [];
}

class ToolSelected extends RoomModelingEvent {
  final RoomModelingTool tool;

  const ToolSelected(this.tool);

  @override
  List<Object?> get props => [tool];
}

class StepChanged extends RoomModelingEvent {
  final RoomModelingStep step;

  const StepChanged(this.step);

  @override
  List<Object?> get props => [step];
}

class WallSelected extends RoomModelingEvent {
  final String? wallId;

  const WallSelected(this.wallId);

  @override
  List<Object?> get props => [wallId];
}

class FurnitureSelected extends RoomModelingEvent {
  final String? furnitureId;

  const FurnitureSelected(this.furnitureId);

  @override
  List<Object?> get props => [furnitureId];
}

class DeleteSelectedWall extends RoomModelingEvent {
  const DeleteSelectedWall();
}

class DeleteSelectedFurniture extends RoomModelingEvent {
  const DeleteSelectedFurniture();
}

class CanvasPanStart extends RoomModelingEvent {
  final Offset position;
  final Size canvasSize;

  const CanvasPanStart(this.position, this.canvasSize);

  @override
  List<Object?> get props => [position, canvasSize];
}

class CanvasPanUpdate extends RoomModelingEvent {
  final Offset position;
  final Size canvasSize;

  const CanvasPanUpdate(this.position, this.canvasSize);

  @override
  List<Object?> get props => [position, canvasSize];
}

class CanvasPanEnd extends RoomModelingEvent {
  const CanvasPanEnd();
}

class CanvasTap extends RoomModelingEvent {
  final Offset position;
  final Size canvasSize;

  const CanvasTap(this.position, this.canvasSize);

  @override
  List<Object?> get props => [position, canvasSize];
}

class UpdateSelectedFurniture extends RoomModelingEvent {
  final Size? size;
  final double? rotation;
  final double? heightMeters;
  final double? sillHeightMeters;
  final double? openingHeightMeters;

  const UpdateSelectedFurniture({
    this.size,
    this.rotation,
    this.heightMeters,
    this.sillHeightMeters,
    this.openingHeightMeters,
  });

  @override
  List<Object?> get props =>
      [size, rotation, heightMeters, sillHeightMeters, openingHeightMeters];
}

class RoomHeightChanged extends RoomModelingEvent {
  final double heightMeters;

  const RoomHeightChanged(this.heightMeters);

  @override
  List<Object?> get props => [heightMeters];
}

class ClearRoom extends RoomModelingEvent {
  const ClearRoom();
}

class DeviceHighlightsUpdated extends RoomModelingEvent {
  final Map<String, Color> highlights;

  const DeviceHighlightsUpdated(this.highlights);

  @override
  List<Object?> get props => [highlights];
}

class RoomPlanImported extends RoomModelingEvent {
  final RoomPlanImportResult plan;

  const RoomPlanImported(this.plan);

  @override
  List<Object?> get props => [plan];
}

/// Request to load available materials from backend.
class LoadMaterials extends RoomModelingEvent {
  const LoadMaterials();
}

/// Provides the loaded materials to the bloc.
class MaterialsLoaded extends RoomModelingEvent {
  final List<AcousticMaterial> materials;

  const MaterialsLoaded(this.materials);

  @override
  List<Object?> get props => [materials];
}

/// Reports a material loading error.
class MaterialsLoadFailed extends RoomModelingEvent {
  final String error;

  const MaterialsLoadFailed(this.error);

  @override
  List<Object?> get props => [error];
}

/// Change the wall material selection.
class WallMaterialChanged extends RoomModelingEvent {
  final AcousticMaterial? material;

  const WallMaterialChanged(this.material);

  @override
  List<Object?> get props => [material];
}

/// Change the floor material selection.
class FloorMaterialChanged extends RoomModelingEvent {
  final AcousticMaterial? material;

  const FloorMaterialChanged(this.material);

  @override
  List<Object?> get props => [material];
}

/// Change the ceiling material selection.
class CeilingMaterialChanged extends RoomModelingEvent {
  final AcousticMaterial? material;

  const CeilingMaterialChanged(this.material);

  @override
  List<Object?> get props => [material];
}
