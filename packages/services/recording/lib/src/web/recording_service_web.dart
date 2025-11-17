import 'package:record/record.dart';

import '../recording_service_interface.dart';
import '../shared/raw_recording_service.dart';

class WebRecordingService extends RawRecordingService {
  WebRecordingService() : super('Web');

  @override
  RecordConfig buildConfig() => rawRecordConfig();
}

RecordingService buildRecordingService() => WebRecordingService();
