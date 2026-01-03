import 'dart:math';
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../bloc/room_modeling_state.dart';
import '../models/furniture.dart';
import '../models/wall.dart';

class RoomPlanImportResult {
  const RoomPlanImportResult({
    required this.walls,
    required this.furniture,
    required this.roomHeightMeters,
    required this.roomPolygon,
  });

  final List<Wall> walls;
  final List<Furniture> furniture;
  final double roomHeightMeters;
  final List<Offset>? roomPolygon;

  bool get isRoomClosed => roomPolygon != null && roomPolygon!.length >= 3;
}

class RoomPlanImporter {
  RoomPlanImporter() : _uuid = const Uuid();

  final Uuid _uuid;

  static const double _pixelsPerMeter = 50.0;
  static const double _padding = 200.0;

  RoomPlanImportResult? tryImport(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    try {
      return import(json);
    } catch (_) {
      return null;
    }
  }

  RoomPlanImportResult import(Map<String, dynamic> json) {
    final room = _extractRoom(json);
    final wallEntries = room != null && room['walls'] is List
        ? (room['walls'] as List)
        : const [];

    final drafts = <_WallDraft>[];
    final points = <Offset>[];

    for (final entry in wallEntries) {
      final map = _asMap(entry);
      if (map == null) continue;
      final start = _pointFromMeters(map['start']);
      final end = _pointFromMeters(map['end']);
      if (start == null || end == null) continue;
      final draft = _WallDraft(
        id: _uuid.v4(),
        start: start,
        end: end,
        source: map,
      );
      drafts.add(draft);
      points
        ..add(start)
        ..add(end);
    }

    final furnitureDrafts = <_FurnitureDraft>[];
    furnitureDrafts.addAll(_buildFurnitureDrafts(room, points));
    furnitureDrafts.addAll(_buildDeviceDrafts(json, points));
    furnitureDrafts.addAll(_buildOpenings(drafts, points));

    final shift = _translationFor(points);

    final walls = drafts
        .map(
          (draft) => Wall(
            id: draft.id,
            start: draft.start + shift,
            end: draft.end + shift,
          ),
        )
        .toList(growable: false);

    final furniture = furnitureDrafts
        .map(
          (draft) => Furniture(
            id: draft.id,
            type: draft.type,
            position: draft.position + shift,
            size: draft.size,
            rotation: draft.rotation,
            attachedWallId: draft.attachedWallId,
            heightMeters: draft.heightMeters,
            sillHeightMeters: draft.sillHeightMeters,
            openingHeightMeters: draft.openingHeightMeters,
          ),
        )
        .toList(growable: false);

    final polygon = _polygonFromWalls(walls);
    final roomHeight = _roomHeightFromRoom(room);

    return RoomPlanImportResult(
      walls: walls,
      furniture: furniture,
      roomHeightMeters: roomHeight,
      roomPolygon: polygon,
    );
  }

  Map<String, dynamic>? _extractRoom(Map<String, dynamic> json) {
    final rooms = json['rooms'];
    if (rooms is List) {
      for (final entry in rooms) {
        final map = _asMap(entry);
        if (map != null) {
          return map;
        }
      }
    }
    return null;
  }

  Offset? _pointFromMeters(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) {
      return null;
    }
    final x = _asNum(map['x'])?.toDouble();
    final z = _asNum(map['z'] ?? map['y'])?.toDouble();
    if (x == null || z == null) {
      return null;
    }
    return Offset(x * _pixelsPerMeter, z * _pixelsPerMeter);
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  num? _asNum(dynamic raw) {
    if (raw is num) {
      return raw;
    }
    if (raw is String) {
      return num.tryParse(raw);
    }
    return null;
  }

  List<_FurnitureDraft> _buildFurnitureDrafts(
    Map<String, dynamic>? room,
    List<Offset> points,
  ) {
    final result = <_FurnitureDraft>[];
    final furnitureEntries = room != null && room['furniture'] is List
        ? (room['furniture'] as List)
        : const [];

    for (final entry in furnitureEntries) {
      final map = _asMap(entry);
      if (map == null) continue;
      final type = _furnitureTypeFromString(map['type']);
      if (type == null) continue;
      final position = _pointFromMeters(map['position']);
      if (position == null) continue;
      final size = _sizeFromDimensions(map['dimensions'], type);
      final rotation = _rotationFromMap(map['rotation']);
      final dims = _asMap(map['dimensions']);
      final heightMeters = _asNum(dims?['height'])?.toDouble();

      result.add(
        _FurnitureDraft(
          id: map['id'] is String ? map['id'] as String : _uuid.v4(),
          type: type,
          position: position,
          size: size,
          rotation: rotation,
          heightMeters: heightMeters,
        ),
      );
      points.add(position);
    }

    return result;
  }

  List<_FurnitureDraft> _buildDeviceDrafts(
    Map<String, dynamic> json,
    List<Offset> points,
  ) {
    final result = <_FurnitureDraft>[];
    result.addAll(
        _parseDeviceList(json['sources'], FurnitureType.speaker, points));
    result.addAll(_parseDeviceList(
        json['microphones'], FurnitureType.microphone, points));
    return result;
  }

  List<_FurnitureDraft> _parseDeviceList(
    dynamic entries,
    FurnitureType type,
    List<Offset> points,
  ) {
    if (entries is! List) {
      return const <_FurnitureDraft>[];
    }
    final defaults = Furniture.defaultSize(type);
    final drafts = <_FurnitureDraft>[];
    for (final entry in entries) {
      final map = _asMap(entry);
      if (map == null) continue;
      final positionArray = map['position_m'];
      if (positionArray is! List || positionArray.length < 2) continue;
      final x = _asNum(positionArray[0])?.toDouble();
      final z = _asNum(positionArray[1])?.toDouble();
      final height = positionArray.length >= 3
          ? _asNum(positionArray[2])?.toDouble()
          : null;
      if (x == null || z == null) continue;
      final position = Offset(x * _pixelsPerMeter, z * _pixelsPerMeter);

      drafts.add(
        _FurnitureDraft(
          id: map['id'] is String ? map['id'] as String : _uuid.v4(),
          type: type,
          position: position,
          size: defaults,
          rotation: 0.0,
          heightMeters: height,
        ),
      );
      points.add(position);
    }
    return drafts;
  }

  List<_FurnitureDraft> _buildOpenings(
    List<_WallDraft> walls,
    List<Offset> points,
  ) {
    final drafts = <_FurnitureDraft>[];
    for (final wall in walls) {
      drafts.addAll(
        _parseOpenings(
          wall: wall,
          entries: wall.source['windows'],
          type: FurnitureType.window,
          points: points,
        ),
      );
      drafts.addAll(
        _parseOpenings(
          wall: wall,
          entries: wall.source['doors'],
          type: FurnitureType.door,
          points: points,
        ),
      );
    }
    return drafts;
  }

  List<_FurnitureDraft> _parseOpenings({
    required _WallDraft wall,
    required dynamic entries,
    required FurnitureType type,
    required List<Offset> points,
  }) {
    if (entries is! List) {
      return const <_FurnitureDraft>[];
    }
    final result = <_FurnitureDraft>[];
    final lengthMeters = _wallLengthMeters(wall);
    final wallVector = wall.end - wall.start;
    final direction = wallVector.distance == 0
        ? const Offset(1, 0)
        : wallVector / wallVector.distance;
    final rotation = atan2(direction.dy, direction.dx);

    for (final entry in entries) {
      final map = _asMap(entry);
      if (map == null) continue;
      final positionMap = _asMap(map['position']);
      final dims = _asMap(map['dimensions']);
      final xLocal = _asNum(positionMap?['x'])?.toDouble() ?? 0.0;
      final relative = lengthMeters == 0
          ? 0.5
          : ((xLocal / lengthMeters) + 0.5).clamp(0.0, 1.0);
      final basePoint = Offset(
        wall.start.dx + wallVector.dx * relative,
        wall.start.dy + wallVector.dy * relative,
      );
      final defaultSize = Furniture.defaultSize(type);
      final widthMeters = _asNum(dims?['width'])?.toDouble();
      final heightMeters = _asNum(dims?['height'])?.toDouble();
      final size = Size(
        widthMeters != null ? widthMeters * _pixelsPerMeter : defaultSize.width,
        defaultSize.height,
      );
      double? sillHeight;
      double? openingHeight;
      if (type == FurnitureType.window) {
        openingHeight = heightMeters ?? Furniture.defaultWindowHeightMeters;
        final center = _asNum(positionMap?['y'])?.toDouble();
        final fallbackCenter = openingHeight / 2.0;
        final actualCenter = center ?? fallbackCenter;
        sillHeight = max(0, actualCenter - (openingHeight / 2.0));
      }

      result.add(
        _FurnitureDraft(
          id: _uuid.v4(),
          type: type,
          position: basePoint,
          size: size,
          rotation: rotation,
          attachedWallId: wall.id,
          heightMeters: type == FurnitureType.door ? heightMeters : null,
          sillHeightMeters: sillHeight,
          openingHeightMeters: openingHeight,
        ),
      );
      points.add(basePoint);
    }

    return result;
  }

  Offset _translationFor(List<Offset> points) {
    if (points.isEmpty) {
      return const Offset(_padding, _padding);
    }
    double minX = double.infinity;
    double minY = double.infinity;
    for (final point in points) {
      if (!point.dx.isFinite || !point.dy.isFinite) continue;
      minX = min(minX, point.dx);
      minY = min(minY, point.dy);
    }
    if (!minX.isFinite || !minY.isFinite) {
      return const Offset(_padding, _padding);
    }
    return Offset(_padding - minX, _padding - minY);
  }

  double _wallLengthMeters(_WallDraft wall) {
    return (wall.end - wall.start).distance / _pixelsPerMeter;
  }

  double _rotationFromMap(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) {
      return 0.0;
    }
    final y = _asNum(map['y'])?.toDouble();
    if (y == null) {
      return 0.0;
    }
    return -y;
  }

  FurnitureType? _furnitureTypeFromString(dynamic raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    switch (raw) {
      case 'table':
        return FurnitureType.table;
      case 'chair':
        return FurnitureType.chair;
      case 'sofa':
        return FurnitureType.sofa;
      case 'bed':
        return FurnitureType.bed;
      case 'bathtub':
        return FurnitureType.bathtub;
      case 'toilet':
        return FurnitureType.toilet;
      case 'sink':
        return FurnitureType.sink;
      case 'door':
        return FurnitureType.door;
      case 'window':
        return FurnitureType.window;
      case 'wardrobe':
      case 'closet':
        return FurnitureType.closet;
      case 'desk':
        return FurnitureType.desk;
      case 'shelf':
        return FurnitureType.shelf;
      case 'stove':
        return FurnitureType.stove;
      case 'fridge':
        return FurnitureType.fridge;
      case 'shower':
        return FurnitureType.shower;
      case 'speaker':
        return FurnitureType.speaker;
      case 'microphone':
        return FurnitureType.microphone;
      default:
        return null;
    }
  }

  Size _sizeFromDimensions(dynamic raw, FurnitureType type) {
    final dims = _asMap(raw);
    final defaults = Furniture.defaultSize(type);
    final widthMeters = _asNum(dims?['width'])?.toDouble();
    final depthMeters = _asNum(dims?['depth'])?.toDouble();
    final widthPx =
        widthMeters != null ? widthMeters * _pixelsPerMeter : defaults.width;
    final depthPx =
        depthMeters != null ? depthMeters * _pixelsPerMeter : defaults.height;
    return Size(widthPx, depthPx);
  }

  double _roomHeightFromRoom(Map<String, dynamic>? room) {
    final dims = _asMap(room?['dimensions']);
    final ceiling = _asMap(room?['ceiling']);
    final height = _asNum(dims?['height'])?.toDouble() ??
        _asNum(ceiling?['height'])?.toDouble();
    if (height == null || !height.isFinite || height <= 0) {
      return RoomModelingState.defaultRoomHeightMeters;
    }
    return height.clamp(2.0, 6.0);
  }

  List<Offset>? _polygonFromWalls(List<Wall> walls) {
    if (walls.length < 3) {
      return null;
    }

    String pointKey(Offset p) =>
        '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}';

    final adjacency = <String, List<String>>{};
    final lookup = <String, Offset>{};

    for (final wall in walls) {
      final startKey = pointKey(wall.start);
      final endKey = pointKey(wall.end);
      lookup[startKey] = wall.start;
      lookup[endKey] = wall.end;
      adjacency.putIfAbsent(startKey, () => []).add(endKey);
      adjacency.putIfAbsent(endKey, () => []).add(startKey);
    }

    if (adjacency.isEmpty) {
      return null;
    }

    final ordered = <Offset>[];
    final visited = <String>{};
    final startKey = adjacency.keys.first;
    String current = startKey;
    String? previous;

    for (int i = 0; i < adjacency.length + 2; i++) {
      final point = lookup[current];
      if (point == null) break;
      ordered.add(point);
      visited.add(current);

      final neighbors = adjacency[current] ?? const [];
      String? next;
      for (final candidate in neighbors) {
        if (candidate == previous) {
          continue;
        }
        if (!visited.contains(candidate)) {
          next = candidate;
          break;
        }
      }

      if (next == null) {
        if (neighbors.contains(startKey) && ordered.length >= 3) {
          return ordered;
        }
        break;
      }

      previous = current;
      current = next;
    }

    return ordered.length >= 3 ? ordered : null;
  }
}

class _WallDraft {
  _WallDraft({
    required this.id,
    required this.start,
    required this.end,
    required this.source,
  });

  final String id;
  final Offset start;
  final Offset end;
  final Map<String, dynamic> source;
}

class _FurnitureDraft {
  _FurnitureDraft({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    required this.rotation,
    this.attachedWallId,
    this.heightMeters,
    this.sillHeightMeters,
    this.openingHeightMeters,
  });

  final String id;
  final FurnitureType type;
  final Offset position;
  final Size size;
  final double rotation;
  final String? attachedWallId;
  final double? heightMeters;
  final double? sillHeightMeters;
  final double? openingHeightMeters;
}
