import 'package:record/record.dart';

import '../shared/raw_recording_service.dart';

class IosRecordingService extends RawRecordingService {
  IosRecordingService() : super('iOS');

  @override
  RecordConfig buildConfig() => rawRecordConfig();
}
