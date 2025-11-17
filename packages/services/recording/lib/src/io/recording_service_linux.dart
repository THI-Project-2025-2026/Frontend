import 'package:record/record.dart';

import '../shared/raw_recording_service.dart';

class LinuxRecordingService extends RawRecordingService {
  LinuxRecordingService() : super('Linux');

  @override
  RecordConfig buildConfig() => rawRecordConfig();
}
