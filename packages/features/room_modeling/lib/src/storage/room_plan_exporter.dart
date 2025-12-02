import 'dart:math';
import 'dart:ui';

import '../bloc/room_modeling_state.dart';
import '../models/furniture.dart';
import '../models/wall.dart';

class RoomPlanExporter {
  static const double pixelsPerMeter = 50.0;
  static const double defaultWallThicknessM = 0.2;
  static const String wallColor = '#e0e0e0';
  static const String windowColor = '#aee3ff';
  static const String doorColor = '#6b3f1f';
  static const String floorColor = '#d4a574';
  static const String ceilingColor = '#ffffff';
  static const String version = '1.0';
  static const double defaultDoorHeightM = 2.1;

  Map<String, dynamic> export(RoomModelingState state) {
    final now = DateTime.now().toUtc().toIso8601String();

    final polygon = state.roomPolygon ?? _polygonFromWalls(state.walls);
    final centroid = (polygon != null && polygon.length >= 3)
        ? _polygonCentroid(polygon)
        : _bboxCenter(_bboxFromWalls(state.walls));

    final wallsJson = <Map<String, dynamic>>[];
    final wallLengthsM = <String, double>{};

    for (final wall in state.walls) {
      final startM = _toMetersCentered(wall.start, centroid);
      final endM = _toMetersCentered(wall.end, centroid);
      final lengthM = (wall.end - wall.start).distance / pixelsPerMeter;
      wallLengthsM[wall.id] = lengthM;

      final wallJson = <String, dynamic>{
        'start': {'x': startM.dx, 'y': 0.0, 'z': startM.dy},
        'end': {'x': endM.dx, 'y': 0.0, 'z': endM.dy},
        'height': state.roomHeightMeters,
        'thickness': defaultWallThicknessM,
        'color': wallColor,
      };
      wallsJson.add(wallJson);
    }

    final openingsByWall = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final f in state.furniture) {
      if (!f.isOpening || f.attachedWallId == null) continue;
      final wallId = f.attachedWallId!;

      final widthM = f.size.width / pixelsPerMeter;
      final isWindow = f.type == FurnitureType.window;
      final heightM = isWindow
          ? (f.openingHeightMeters ?? Furniture.defaultWindowHeightMeters)
          : defaultDoorHeightM;
      final yCenterM = isWindow
          ? (f.sillHeightMeters ?? Furniture.defaultWindowSillHeightMeters) +
              heightM / 2.0
          : heightM / 2.0;

      // Relative position along the attached wall mapped to local X (meters)
      final wall = state.walls.firstWhere(
        (w) => w.id == wallId,
        orElse: () => const Wall(id: '_', start: Offset.zero, end: Offset(1, 0)),
      );
      final t = _relativePositionAlongWall(wall, f.position);
      final lengthM = wallLengthsM[wallId] ?? 0.0;
      final xLocal = (t - 0.5) * lengthM;

      final openingJson = {
        'position': {'x': xLocal, 'y': yCenterM, 'z': 0.0},
        'dimensions': {'width': widthM, 'height': heightM, 'depth': 0.0},
        'color': isWindow ? windowColor : doorColor,
      };

      final bucket = openingsByWall.putIfAbsent(
        wallId,
        () => {
          'windows': <Map<String, dynamic>>[],
          'doors': <Map<String, dynamic>>[],
        },
      );
      if (isWindow) {
        bucket['windows']!.add(openingJson);
      } else {
        bucket['doors']!.add(openingJson);
      }
    }

    for (int i = 0; i < state.walls.length; i++) {
      final wall = state.walls[i];
      final openings = openingsByWall[wall.id];
      if (openings == null) continue;
      if (openings['windows']!.isNotEmpty) {
        (wallsJson[i])['windows'] = openings['windows'];
      }
      if (openings['doors']!.isNotEmpty) {
        (wallsJson[i])['doors'] = openings['doors'];
      }
    }

    final furnitureJson = state.furniture
        .where((f) => !f.isOpening)
        .map((f) => _mapFurniture(f, centroid))
        .toList();

    final bbox = polygon != null && polygon.length >= 3
        ? _bboxFromPolygon(polygon)
        : _bboxFromWalls(state.walls);
    final widthM = (bbox.right - bbox.left) / pixelsPerMeter;
    final depthM = (bbox.bottom - bbox.top) / pixelsPerMeter;

    final room = {
      'id': 'room-1',
      'name': 'Room',
      'dimensions': {
        'width': widthM,
        'height': state.roomHeightMeters,
        'depth': depthM,
      },
      'walls': wallsJson,
      'furniture': furnitureJson,
      'floor': {'color': floorColor, 'material': 'wood'},
      'ceiling': {'color': ceilingColor, 'height': state.roomHeightMeters},
    };

    return {
      'version': version,
      'rooms': [room],
      'metadata': {'created': now, 'modified': now},
    };
  }

  Map<String, dynamic> _mapFurniture(Furniture f, Offset centroid) {
    final widthM = f.size.width / pixelsPerMeter;
    final depthM = f.size.height / pixelsPerMeter;
    final posM = _toMetersCentered(f.position, centroid);

    final typeString = _typeToString(f.type);
    final heightM = _defaultFurnitureHeightMeters(f.type);
    final color = _defaultFurnitureColor(f.type);

    return {
      'id': f.id,
      'type': typeString,
      'position': {'x': posM.dx, 'y': 0.0, 'z': posM.dy},
      'rotation': {'x': 0.0, 'y': f.rotation, 'z': 0.0},
      'dimensions': {'width': widthM, 'height': heightM, 'depth': depthM},
      'color': color,
    };
  }

  String _typeToString(FurnitureType t) {
    switch (t) {
      case FurnitureType.table:
        return 'table';
      case FurnitureType.chair:
        return 'chair';
      case FurnitureType.sofa:
        return 'sofa';
      case FurnitureType.bed:
        return 'bed';
      case FurnitureType.bathtub:
        return 'bathtub';
      case FurnitureType.toilet:
        return 'toilet';
      case FurnitureType.sink:
        return 'sink';
      case FurnitureType.door:
        return 'door';
      case FurnitureType.window:
        return 'window';
    }
  }

  double _defaultFurnitureHeightMeters(FurnitureType t) {
    switch (t) {
      case FurnitureType.table:
        return 0.75;
      case FurnitureType.chair:
        return 1.0;
      case FurnitureType.sofa:
        return 0.8;
      case FurnitureType.bed:
        return 0.6;
      case FurnitureType.bathtub:
        return 0.6;
      case FurnitureType.toilet:
        return 0.8;
      case FurnitureType.sink:
        return 0.9;
      case FurnitureType.door:
      case FurnitureType.window:
        return 0.0;
    }
  }

  String _defaultFurnitureColor(FurnitureType t) {
    switch (t) {
      case FurnitureType.table:
        return '#8B4513';
      case FurnitureType.chair:
        return '#4a4a4a';
      case FurnitureType.sofa:
        return '#708090';
      case FurnitureType.bed:
        return '#ffffff';
      case FurnitureType.bathtub:
        return '#e0e0e0';
      case FurnitureType.toilet:
        return '#e0e0e0';
      case FurnitureType.sink:
        return '#cccccc';
      case FurnitureType.door:
        return doorColor;
      case FurnitureType.window:
        return windowColor;
    }
  }

  Offset _toMetersCentered(Offset p, Offset centerPx) {
    return Offset(
      (p.dx - centerPx.dx) / pixelsPerMeter,
      (p.dy - centerPx.dy) / pixelsPerMeter,
    );
  }

  double _relativePositionAlongWall(Wall wall, Offset point) {
    final vector = wall.end - wall.start;
    final lenSquared = vector.dx * vector.dx + vector.dy * vector.dy;
    if (lenSquared < 1e-6) return 0.5;
    final projection = ((point.dx - wall.start.dx) * vector.dx +
            (point.dy - wall.start.dy) * vector.dy) /
        lenSquared;
    return projection.clamp(0.0, 1.0);
  }

  List<Offset>? _polygonFromWalls(List<Wall> walls) {
    if (walls.length < 3) return null;
    final points = <Offset>[];
    final used = <int>{};
    int? startIdx;
    for (int i = 0; i < walls.length && startIdx == null; i++) {
      startIdx = i;
    }
    if (startIdx == null) return null;
    var current = walls[startIdx];
    points.add(current.start);
    points.add(current.end);
    used.add(startIdx);
    for (;;) {
      bool extended = false;
      for (int i = 0; i < walls.length; i++) {
        if (used.contains(i)) continue;
        final w = walls[i];
        if ((w.start - points.last).distance < 0.1) {
          points.add(w.end);
          used.add(i);
          extended = true;
        } else if ((w.end - points.last).distance < 0.1) {
          points.add(w.start);
          used.add(i);
          extended = true;
        }
      }
      if (!extended) break;
    }
    if (points.length < 3) return null;
    return points;
  }

  Rect _bboxFromPolygon(List<Offset> poly) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in poly) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect _bboxFromWalls(List<Wall> walls) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final w in walls) {
      for (final p in [w.start, w.end]) {
        minX = min(minX, p.dx);
        minY = min(minY, p.dy);
        maxX = max(maxX, p.dx);
        maxY = max(maxY, p.dy);
      }
    }
    if (minX == double.infinity) return const Rect.fromLTWH(0, 0, 1, 1);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _bboxCenter(Rect r) => Offset((r.left + r.right) / 2, (r.top + r.bottom) / 2);

  Offset _polygonCentroid(List<Offset> polygon) {
    double signedArea = 0;
    double cx = 0, cy = 0;
    for (int i = 0; i < polygon.length; i++) {
      final p = polygon[i];
      final n = polygon[(i + 1) % polygon.length];
      final cross = p.dx * n.dy - n.dx * p.dy;
      signedArea += cross;
      cx += (p.dx + n.dx) * cross;
      cy += (p.dy + n.dy) * cross;
    }
    signedArea *= 0.5;
    if (signedArea.abs() < 1e-6) {
      double sx = 0, sy = 0;
      for (final p in polygon) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / polygon.length, sy / polygon.length);
    }
    return Offset(cx / (6 * signedArea), cy / (6 * signedArea));
  }
}
