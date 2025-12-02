import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'room_plan_storage.dart';

RoomPlanStorage createRoomPlanStorage() => _IoRoomPlanStorage();

class _IoRoomPlanStorage implements RoomPlanStorage {
  @override
  Future<void> save(Map<String, dynamic> json) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/room_plan.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {
      // Optionally log errors; safe to ignore for silent persistence
    }
  }
}
