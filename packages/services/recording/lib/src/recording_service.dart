import 'recording_service_interface.dart';
import 'recording_service_stub.dart'
    if (dart.library.html) 'web/recording_service_web.dart'
    if (dart.library.io) 'io/recording_service_io.dart';

export 'recording_service_interface.dart';

/// Returns the platform aware implementation.
RecordingService createRecordingService() => buildRecordingService();
