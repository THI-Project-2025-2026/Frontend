// IO implementation for loading room plan JSON from file system
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Loads room plan JSON from application documents directory
/// Returns null if file doesn't exist
Future<String?> loadRoomPlanJson() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/room_plan.json');
    if (await file.exists()) {
      return await file.readAsString();
    }
    return null;
  } catch (e) {
    return null;
  }
}
