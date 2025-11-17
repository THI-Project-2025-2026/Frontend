import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:l10n_service/l10n_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<AppConstants>()) {
    await AppConstants.initialize();
    getIt.registerSingleton<AppConstants>(AppConstants());
  }

  if (!getIt.isRegistered<JsonHotReloadBloc>()) {
    final jsonHotReloadBloc = JsonHotReloadBloc();
    getIt.registerSingleton<JsonHotReloadBloc>(jsonHotReloadBloc);

    if (kDebugMode && !kIsWeb) {
      jsonHotReloadBloc.add(StartFileWatching());
    }
  }
}
