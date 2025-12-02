import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:room_modeling/src/bloc/room_modeling_state.dart';
import 'package:room_modeling/src/models/furniture.dart';
import 'package:room_modeling/src/models/wall.dart';
import 'package:room_modeling/src/storage/room_plan_exporter.dart';

void main() {
  test('exports basic room with walls and openings', () {
    final walls = <Wall>[
      const Wall(id: 'w1', start: Offset(-250, -250), end: Offset(250, -250)),
      const Wall(id: 'w2', start: Offset(250, -250), end: Offset(250, 250)),
      const Wall(id: 'w3', start: Offset(250, 250), end: Offset(-250, 250)),
      const Wall(id: 'w4', start: Offset(-250, 250), end: Offset(-250, -250)),
    ];

    final furniture = <Furniture>[
      // Window on w1 centered
      Furniture(
        id: 'f1',
        type: FurnitureType.window,
        position: const Offset(0, -250),
        rotation: 0,
        size: const Size(75, 10),
        attachedWallId: 'w1',
        sillHeightMeters: 1.0,
        openingHeightMeters: 1.2,
      ),
      // Door on w2
      Furniture(
        id: 'f2',
        type: FurnitureType.door,
        position: const Offset(250, 0),
        rotation: 0,
        size: const Size(45, 10),
        attachedWallId: 'w2',
      ),
      // A table inside
      Furniture(
        id: 't1',
        type: FurnitureType.table,
        position: const Offset(0, 0),
        rotation: 0,
        size: const Size(80, 50),
      ),
    ];

    final state = RoomModelingState(
      walls: walls,
      furniture: furniture,
      isRoomClosed: true,
      roomPolygon: const [
        Offset(-250, -250),
        Offset(250, -250),
        Offset(250, 250),
        Offset(-250, 250),
      ],
    );

    final exporter = RoomPlanExporter();
    final json = exporter.export(state);

    expect(json['version'], '1.0');
    expect(json['rooms'], isA<List>());
    final room = (json['rooms'] as List).first as Map<String, dynamic>;
    expect(room['walls'], isA<List>());
    final wallsJson = room['walls'] as List;
    expect(wallsJson.length, 4);

    // w1 has window; w2 has door
    final w1 = wallsJson[0] as Map<String, dynamic>;
    final w2 = wallsJson[1] as Map<String, dynamic>;
    expect((w1['windows'] as List).length, 1);
    expect((w2['doors'] as List).length, 1);

    // furniture excludes openings
    final furn = room['furniture'] as List;
    expect(furn.length, 1);
    final f0 = furn.first as Map<String, dynamic>;
    expect(f0['type'], 'table');
  });
}
