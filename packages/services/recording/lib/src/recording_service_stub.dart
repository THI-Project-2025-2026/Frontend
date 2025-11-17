import 'package:record/record.dart';

import 'recording_service_interface.dart';

RecordingService buildRecordingService() => _UnsupportedRecordingService();

class _UnsupportedRecordingService implements RecordingService {
  UnsupportedError _unsupportedError() =>
      UnsupportedError('RecordingService is not available on this platform');

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> start({required String filePath}) =>
      Future<void>.error(_unsupportedError());

  @override
  Future<String?> stop() => Future<String?>.error(_unsupportedError());

  @override
  Future<void> cancel() => Future<void>.error(_unsupportedError());

  @override
  Future<bool> isRecording() async => false;

  @override
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 200),
  }) => Stream<Amplitude>.error(_unsupportedError());

  @override
  Future<void> dispose() => Future<void>.error(_unsupportedError());
}
