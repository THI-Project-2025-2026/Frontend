import 'dart:convert';
import 'dart:html' as html;

import 'room_plan_storage.dart';

RoomPlanStorage createRoomPlanStorage() => _WebRoomPlanStorage();

class _WebRoomPlanStorage implements RoomPlanStorage {
  static const _key = 'room_plan.json';

  @override
  Future<void> save(Map<String, dynamic> json) async {
    try {
      html.window.localStorage[_key] = jsonEncode(json);
    } catch (_) {
      // Ignore storage failures in web localStorage
    }
  }
}
