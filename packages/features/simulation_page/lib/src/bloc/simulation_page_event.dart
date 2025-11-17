part of 'simulation_page_bloc.dart';

@immutable
sealed class SimulationPageEvent {
  const SimulationPageEvent();
}

/// Event for any change to the room dimensions.
class SimulationRoomDimensionChanged extends SimulationPageEvent {
  const SimulationRoomDimensionChanged({this.width, this.length, this.height});

  final double? width;
  final double? length;
  final double? height;
}

/// Event fired when the palette selection changes.
class SimulationFurnitureTypeSelected extends SimulationPageEvent {
  const SimulationFurnitureTypeSelected(this.kind);

  final SimulationFurnitureKind? kind;
}

/// Places or replaces furniture at a grid position.
class SimulationFurniturePlaced extends SimulationPageEvent {
  const SimulationFurniturePlaced({required this.gridX, required this.gridY});

  final int gridX;
  final int gridY;
}

/// Removes any furniture item occupying the grid cell.
class SimulationFurnitureRemoved extends SimulationPageEvent {
  const SimulationFurnitureRemoved({required this.gridX, required this.gridY});

  final int gridX;
  final int gridY;
}

/// Clears the current furniture layout.
class SimulationFurnitureCleared extends SimulationPageEvent {
  const SimulationFurnitureCleared();
}

/// Applies a predefined room preset.
class SimulationRoomPresetApplied extends SimulationPageEvent {
  const SimulationRoomPresetApplied({required this.index});

  final int index;
}
