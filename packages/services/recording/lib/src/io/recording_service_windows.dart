import 'package:record/record.dart';

import '../shared/raw_recording_service.dart';

class WindowsRecordingService extends RawRecordingService {
  WindowsRecordingService() : super('Windows');

  @override
  RecordConfig buildConfig() => rawRecordConfig();
}
