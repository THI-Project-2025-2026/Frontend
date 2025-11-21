import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/wall.dart';
import '../models/furniture.dart';

enum RoomModelingTool {
  wall,
  door,
  window,
  chair,
  table,
  sofa,
  bed,
  select, // For moving things around
}

class RoomModelingState extends Equatable {
  final List<Wall> walls;
  final List<Furniture> furniture;
  final RoomModelingTool activeTool;
  final bool isRoomClosed;

  // Dragging state
  final Offset? dragStart;
  final Offset? dragCurrent;
  final Wall? tempWall; // The wall currently being drawn

  const RoomModelingState({
    this.walls = const [],
    this.furniture = const [],
    this.activeTool = RoomModelingTool.wall,
    this.isRoomClosed = false,
    this.dragStart,
    this.dragCurrent,
    this.tempWall,
  });

  RoomModelingState copyWith({
    List<Wall>? walls,
    List<Furniture>? furniture,
    RoomModelingTool? activeTool,
    bool? isRoomClosed,
    Offset? dragStart,
    Offset? dragCurrent,
    Wall? tempWall,
    bool clearDrag = false,
  }) {
    return RoomModelingState(
      walls: walls ?? this.walls,
      furniture: furniture ?? this.furniture,
      activeTool: activeTool ?? this.activeTool,
      isRoomClosed: isRoomClosed ?? this.isRoomClosed,
      dragStart: clearDrag ? null : (dragStart ?? this.dragStart),
      dragCurrent: clearDrag ? null : (dragCurrent ?? this.dragCurrent),
      tempWall: clearDrag ? null : (tempWall ?? this.tempWall),
    );
  }

  @override
  List<Object?> get props => [
    walls,
    furniture,
    activeTool,
    isRoomClosed,
    dragStart,
    dragCurrent,
    tempWall,
  ];
}
