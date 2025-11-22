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
  bathtub,
  toilet,
  sink,
}

enum RoomModelingStep {
  structure,
  furnishing,
}

enum FurnitureInteraction {
  none,
  move,
  resize,
  rotate,
}

class RoomModelingState extends Equatable {
  final List<Wall> walls;
  final List<Furniture> furniture;
  final RoomModelingTool activeTool;
  final RoomModelingStep currentStep;
  final bool isRoomClosed;
  final String? selectedWallId;
  final String? selectedFurnitureId;
  final FurnitureInteraction furnitureInteraction;
  final Furniture? initialFurnitureState; // State at start of interaction
  final int? movingWallEndpoint; // 0 for start, 1 for end
  final Map<String, int>
      movingWallEndpoints; // Map of Wall ID to endpoint index (0 or 1)

  // Dragging state
  final Offset? dragStart;
  final Offset? dragCurrent;
  final Wall? tempWall; // The wall currently being drawn
  final List<SnapGuideLine> snapGuides;
  final List<Offset>? roomPolygon;

  const RoomModelingState({
    this.walls = const [],
    this.furniture = const [],
    this.activeTool = RoomModelingTool.wall,
    this.currentStep = RoomModelingStep.structure,
    this.isRoomClosed = false,
    this.selectedWallId,
    this.selectedFurnitureId,
    this.furnitureInteraction = FurnitureInteraction.none,
    this.initialFurnitureState,
    this.movingWallEndpoint,
    this.movingWallEndpoints = const {},
    this.dragStart,
    this.dragCurrent,
    this.tempWall,
    this.snapGuides = const [],
    this.roomPolygon,
  });

  RoomModelingState copyWith({
    List<Wall>? walls,
    List<Furniture>? furniture,
    RoomModelingTool? activeTool,
    RoomModelingStep? currentStep,
    bool? isRoomClosed,
    String? selectedWallId,
    String? selectedFurnitureId,
    FurnitureInteraction? furnitureInteraction,
    Furniture? initialFurnitureState,
    int? movingWallEndpoint,
    Map<String, int>? movingWallEndpoints,
    Offset? dragStart,
    Offset? dragCurrent,
    Wall? tempWall,
    List<SnapGuideLine>? snapGuides,
    List<Offset>? roomPolygon,
    bool clearDrag = false,
    bool clearSelection = false,
    bool clearSnapGuide = false,
  }) {
    return RoomModelingState(
      walls: walls ?? this.walls,
      furniture: furniture ?? this.furniture,
      activeTool: activeTool ?? this.activeTool,
      currentStep: currentStep ?? this.currentStep,
      isRoomClosed: isRoomClosed ?? this.isRoomClosed,
      selectedWallId:
          clearSelection ? null : (selectedWallId ?? this.selectedWallId),
      selectedFurnitureId: clearSelection
          ? null
          : (selectedFurnitureId ?? this.selectedFurnitureId),
      furnitureInteraction: clearDrag
          ? FurnitureInteraction.none
          : (furnitureInteraction ?? this.furnitureInteraction),
      initialFurnitureState: clearDrag
          ? null
          : (initialFurnitureState ?? this.initialFurnitureState),
      movingWallEndpoint:
          clearDrag ? null : (movingWallEndpoint ?? this.movingWallEndpoint),
      movingWallEndpoints: clearDrag
          ? const {}
          : (movingWallEndpoints ?? this.movingWallEndpoints),
      dragStart: clearDrag ? null : (dragStart ?? this.dragStart),
      dragCurrent: clearDrag ? null : (dragCurrent ?? this.dragCurrent),
      tempWall: clearDrag ? null : (tempWall ?? this.tempWall),
      snapGuides: clearDrag || clearSnapGuide
          ? const []
          : (snapGuides ?? this.snapGuides),
      roomPolygon: roomPolygon ?? this.roomPolygon,
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
        selectedFurnitureId,
        furnitureInteraction,
        initialFurnitureState,
        movingWallEndpoint,
        movingWallEndpoints,
        dragStart,
        dragCurrent,
        tempWall,
        snapGuides,
        roomPolygon,
      ];
}

class SnapGuideLine extends Equatable {
  final Offset start;
  final Offset end;

  const SnapGuideLine(this.start, this.end);

  @override
  List<Object?> get props => [start, end];
}
