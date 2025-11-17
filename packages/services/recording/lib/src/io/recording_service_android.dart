import 'package:record/record.dart';

import '../shared/raw_recording_service.dart';

class AndroidRecordingService extends RawRecordingService {
  AndroidRecordingService() : super('Android');

  @override
  RecordConfig buildConfig() => rawRecordConfig(
    androidConfig: const AndroidRecordConfig(
      audioSource: AndroidAudioSource.unprocessed,
      manageBluetooth: false,
      speakerphone: false,
      muteAudio: false,
      useLegacy: false,
      audioManagerMode: AudioManagerMode.modeNormal,
    ),
  );
}
