# Recording Service

Raw audio recording service built on top of the [`record`](https://pub.dev/packages/record) plugin. Each supported platform (Android, iOS, macOS, Windows, Linux, Web) exposes its own implementation so the service can switch automatically at runtime.

```dart
import 'package:recording_service/recording_service.dart';

final RecordingService recorder = createRecordingService();

Future<void> capture() async {
  if (!await recorder.hasPermission()) {
    return;
  }

  await recorder.start(filePath: '/tmp/sonalyze_raw.wav');
  // ...
  final path = await recorder.stop();
}
```

The service disables every available post-processing toggle (noise suppression, echo cancellation, auto gain, etc.) and records to lossless WAV with 48 kHz / 2 channel PCM to keep the audio as raw as possible.

To guarantee support on every target the package directly depends on the federated implementations `record_android`, `record_ios`, `record_linux`, `record_macos`, `record_web`, and `record_windows`.
