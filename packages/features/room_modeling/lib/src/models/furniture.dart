import 'dart:ui';
import 'package:equatable/equatable.dart';

enum FurnitureType {
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

class Furniture extends Equatable {
  static const double defaultWindowSillHeightMeters = 0.9;
  static const double defaultWindowHeightMeters = 1.2;

  final String id;
  final FurnitureType type;
  final Offset position;
  final double rotation;
  final Size size;
  final String? attachedWallId; // For doors/windows
  final double? sillHeightMeters;
  final double? heightMeters;
  final double? openingHeightMeters;

  bool get isDevice =>
      type == FurnitureType.speaker || type == FurnitureType.microphone;

  static bool isOpeningType(FurnitureType type) {
    return type == FurnitureType.door || type == FurnitureType.window;
  }

  const Furniture({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.attachedWallId,
    this.heightMeters,
    this.sillHeightMeters,
    this.openingHeightMeters,
  });

  Furniture copyWith({
    String? id,
    FurnitureType? type,
    Offset? position,
    double? rotation,
    Size? size,
    String? attachedWallId,
    double? heightMeters,
    double? sillHeightMeters,
    double? openingHeightMeters,
  }) {
    return Furniture(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      size: size ?? this.size,
      attachedWallId: attachedWallId ?? this.attachedWallId,
      heightMeters: heightMeters ?? this.heightMeters,
      sillHeightMeters: sillHeightMeters ?? this.sillHeightMeters,
      openingHeightMeters: openingHeightMeters ?? this.openingHeightMeters,
    );
  }

  bool get isOpening => Furniture.isOpeningType(type);

  @override
  List<Object?> get props => [
        id,
        type,
        position,
        rotation,
        size,
        attachedWallId,
        heightMeters,
        sillHeightMeters,
        openingHeightMeters,
      ];

  static Size defaultSize(FurnitureType type) {
    // Scale: 50 units = 1 meter
    switch (type) {
      case FurnitureType.door:
        return const Size(45, 10); // ~0.9m width
      case FurnitureType.window:
        return const Size(50, 10); // ~1.0m width
      case FurnitureType.chair:
        return const Size(25, 25); // ~0.5m x 0.5m
      case FurnitureType.table:
        return const Size(80, 50); // ~1.6m x 1.0m
      case FurnitureType.sofa:
        return const Size(110, 45); // ~2.2m x 0.9m
      case FurnitureType.bed:
        return const Size(80, 100); // ~1.6m x 2.0m
      case FurnitureType.bathtub:
        return const Size(85, 35); // ~1.7m x 0.7m
      case FurnitureType.toilet:
        return const Size(20, 35); // ~0.4m x 0.7m
      case FurnitureType.sink:
        return const Size(30, 25); // ~0.6m x 0.5m
      case FurnitureType.wardrobe:
        return const Size(100, 30); // ~2.0m x 0.6m
      case FurnitureType.desk:
        return const Size(60, 40); // ~1.2m x 0.8m
      case FurnitureType.shelf:
        return const Size(80, 20); // ~1.6m x 0.4m
      case FurnitureType.stove:
        return const Size(30, 30); // ~0.6m x 0.6m
      case FurnitureType.fridge:
        return const Size(30, 35); // ~0.6m x 0.7m
      case FurnitureType.shower:
        return const Size(45, 45); // ~0.9m x 0.9m
      case FurnitureType.speaker:
        return const Size(24, 24); // ~0.48m x 0.48m
      case FurnitureType.microphone:
        return const Size(18, 18); // ~0.36m x 0.36m
    }
  }
}
