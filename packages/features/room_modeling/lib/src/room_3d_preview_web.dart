// Web implementation for loading room plan JSON from localStorage
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Loads room plan JSON from browser localStorage
/// Returns null if not found
Future<String?> loadRoomPlanJson() async {
  try {
    return html.window.localStorage['room_plan.json'];
  } catch (e) {
    return null;
  }
}
