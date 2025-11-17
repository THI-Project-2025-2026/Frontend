import 'dart:io';

import '../recording_service_interface.dart';
import 'recording_service_android.dart';
import 'recording_service_ios.dart';
import 'recording_service_linux.dart';
import 'recording_service_macos.dart';
import 'recording_service_windows.dart';

RecordingService buildRecordingService() {
  if (Platform.isAndroid) {
    return AndroidRecordingService();
  }

  if (Platform.isIOS) {
    return IosRecordingService();
  }

  if (Platform.isMacOS) {
    return MacosRecordingService();
  }

  if (Platform.isWindows) {
    return WindowsRecordingService();
  }

  if (Platform.isLinux) {
    return LinuxRecordingService();
  }

  throw UnsupportedError(
    'RecordingService is not implemented for ${Platform.operatingSystem}',
  );
}
