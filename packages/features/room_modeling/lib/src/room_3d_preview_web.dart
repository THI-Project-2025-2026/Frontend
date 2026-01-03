// Web implementation for loading room plan JSON from localStorage
import 'package:web/web.dart' as web;

/// Loads room plan JSON from browser localStorage
/// Returns null if not found
Future<String?> loadRoomPlanJson() async {
  try {
    return web.window.localStorage.getItem('room_plan.json');
  } catch (_) {
    return null;
  }
}
