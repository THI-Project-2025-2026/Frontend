import 'room_plan_storage_io.dart' if (dart.library.html) 'room_plan_storage_web.dart';

abstract class RoomPlanStorage {
  Future<void> save(Map<String, dynamic> json);

  factory RoomPlanStorage() => createRoomPlanStorage();
}
