import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../models/wall.dart';
import '../models/furniture.dart';

/// Represents an acoustic material with its properties.
class AcousticMaterial extends Equatable {
  final String id;
  final String displayName;
  final double absorption;
  final double scattering;

  const AcousticMaterial({
    required this.id,
    required this.displayName,
    required this.absorption,
    required this.scattering,
  });

  /// Default material when none is selected
  static const AcousticMaterial defaultMaterial = AcousticMaterial(
    id: 'default',
    displayName: 'Default',
    absorption: 0.20,
    scattering: 0.05,
  );

  @override
  List<Object?> get props => [id, displayName, absorption, scattering];
}

/// Holds the selected materials for walls, floor, and ceiling.
class RoomMaterials extends Equatable {
  final AcousticMaterial? wallMaterial;
  final AcousticMaterial? floorMaterial;
  final AcousticMaterial? ceilingMaterial;

  const RoomMaterials({
    this.wallMaterial,
    this.floorMaterial,
    this.ceilingMaterial,
  });

  RoomMaterials copyWith({
    AcousticMaterial? wallMaterial,
    AcousticMaterial? floorMaterial,
    AcousticMaterial? ceilingMaterial,
    bool clearWall = false,
    bool clearFloor = false,
    bool clearCeiling = false,
  }) {
    return RoomMaterials(
      wallMaterial: clearWall ? null : (wallMaterial ?? this.wallMaterial),
      floorMaterial: clearFloor ? null : (floorMaterial ?? this.floorMaterial),
      ceilingMaterial:
          clearCeiling ? null : (ceilingMaterial ?? this.ceilingMaterial),
    );
  }

  @override
  List<Object?> get props => [wallMaterial, floorMaterial, ceilingMaterial];
}

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
  wardrobe,
  desk,
  shelf,
  stove,
  fridge,
  shower,
  speaker,
  microphone,
}

enum RoomModelingStep {
  structure,
  furnishing,
  audio,
}

enum FurnitureInteraction {
  none,
  move,
  resize,
  rotate,
}

class RoomModelingState extends Equatable {
  static const double defaultRoomHeightMeters = 2.5;

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
  final double roomHeightMeters;
  final Map<String, Color> deviceHighlights;

  // Material selection state
  final List<AcousticMaterial> availableMaterials;
  final RoomMaterials roomMaterials;
  final bool isMaterialsLoading;
  final String? materialsError;

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
    this.roomHeightMeters = defaultRoomHeightMeters,
    this.deviceHighlights = const {},
    this.availableMaterials = const [],
    this.roomMaterials = const RoomMaterials(),
    this.isMaterialsLoading = false,
    this.materialsError,
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
    double? roomHeightMeters,
    Map<String, Color>? deviceHighlights,
    List<AcousticMaterial>? availableMaterials,
    RoomMaterials? roomMaterials,
    bool? isMaterialsLoading,
    String? materialsError,
    bool clearDrag = false,
    bool clearSelection = false,
    bool clearSnapGuide = false,
    bool clearHighlights = false,
    bool clearMaterialsError = false,
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
      roomHeightMeters: roomHeightMeters ?? this.roomHeightMeters,
      deviceHighlights: clearHighlights
          ? const {}
          : (deviceHighlights ?? this.deviceHighlights),
      availableMaterials: availableMaterials ?? this.availableMaterials,
      roomMaterials: roomMaterials ?? this.roomMaterials,
      isMaterialsLoading: isMaterialsLoading ?? this.isMaterialsLoading,
      materialsError:
          clearMaterialsError ? null : (materialsError ?? this.materialsError),
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
        roomHeightMeters,
        deviceHighlights,
        availableMaterials,
        roomMaterials,
        isMaterialsLoading,
        materialsError,
      ];
}

class SnapGuideLine extends Equatable {
  final Offset start;
  final Offset end;

  const SnapGuideLine(this.start, this.end);

  @override
  List<Object?> get props => [start, end];
}
