import 'dart:ui';
import 'package:equatable/equatable.dart';

enum FurnitureType { door, window, chair, table, sofa, bed }

class Furniture extends Equatable {
  final String id;
  final FurnitureType type;
  final Offset position;
  final double rotation;
  final String? attachedWallId; // For doors/windows

  const Furniture({
    required this.id,
    required this.type,
    required this.position,
    this.rotation = 0.0,
    this.attachedWallId,
  });

  Furniture copyWith({
    String? id,
    FurnitureType? type,
    Offset? position,
    double? rotation,
    String? attachedWallId,
  }) {
    return Furniture(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      attachedWallId: attachedWallId ?? this.attachedWallId,
    );
  }

  @override
  List<Object?> get props => [id, type, position, rotation, attachedWallId];
}
