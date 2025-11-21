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

class CanvasPanStart extends RoomModelingEvent {
  final Offset position;

  const CanvasPanStart(this.position);

  @override
  List<Object?> get props => [position];
}

class CanvasPanUpdate extends RoomModelingEvent {
  final Offset position;

  const CanvasPanUpdate(this.position);

  @override
  List<Object?> get props => [position];
}

class CanvasPanEnd extends RoomModelingEvent {
  const CanvasPanEnd();
}

class CanvasTap extends RoomModelingEvent {
  final Offset position;

  const CanvasTap(this.position);

  @override
  List<Object?> get props => [position];
}

class ClearRoom extends RoomModelingEvent {
  const ClearRoom();
}
