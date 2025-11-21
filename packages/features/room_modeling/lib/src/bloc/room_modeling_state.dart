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
}

enum RoomModelingStep {
  structure,
  furnishing,
}

class RoomModelingState extends Equatable {
  final List<Wall> walls;
  final List<Furniture> furniture;
  final RoomModelingTool activeTool;
  final RoomModelingStep currentStep;
  final bool isRoomClosed;
  final String? selectedWallId;
  final int? movingWallEndpoint; // 0 for start, 1 for end

  // Dragging state
  final Offset? dragStart;
  final Offset? dragCurrent;
  final Wall? tempWall; // The wall currently being drawn

  const RoomModelingState({
    this.walls = const [],
    this.furniture = const [],
    this.activeTool = RoomModelingTool.wall,
    this.currentStep = RoomModelingStep.structure,
    this.isRoomClosed = false,
    this.selectedWallId,
    this.movingWallEndpoint,
    this.dragStart,
    this.dragCurrent,
    this.tempWall,
  });

  RoomModelingState copyWith({
    List<Wall>? walls,
    List<Furniture>? furniture,
    RoomModelingTool? activeTool,
    RoomModelingStep? currentStep,
    bool? isRoomClosed,
    String? selectedWallId,
    int? movingWallEndpoint,
    Offset? dragStart,
    Offset? dragCurrent,
    Wall? tempWall,
    bool clearDrag = false,
    bool clearSelection = false,
  }) {
    return RoomModelingState(
      walls: walls ?? this.walls,
      furniture: furniture ?? this.furniture,
      activeTool: activeTool ?? this.activeTool,
      currentStep: currentStep ?? this.currentStep,
      isRoomClosed: isRoomClosed ?? this.isRoomClosed,
      selectedWallId:
          clearSelection ? null : (selectedWallId ?? this.selectedWallId),
      movingWallEndpoint:
          clearDrag ? null : (movingWallEndpoint ?? this.movingWallEndpoint),
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
        currentStep,
        isRoomClosed,
        selectedWallId,
        movingWallEndpoint,
        dragStart,
        dragCurrent,
        tempWall,
      ];
}
