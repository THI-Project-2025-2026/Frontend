import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'room_modeling_state.dart';

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
  final double? sillHeightMeters;
  final double? openingHeightMeters;

  const UpdateSelectedFurniture({
    this.size,
    this.rotation,
    this.sillHeightMeters,
    this.openingHeightMeters,
  });

  @override
  List<Object?> get props =>
      [size, rotation, sillHeightMeters, openingHeightMeters];
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
