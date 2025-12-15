import 'package:backend_gateway/backend_gateway.dart';
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

  _registerGatewayDependencies();
}

void _registerGatewayDependencies() {
  if (!getIt.isRegistered<GatewayConfig>()) {
    getIt.registerLazySingleton<GatewayConfig>(_buildGatewayConfig);
  }

  if (!getIt.isRegistered<GatewayConnectionRepository>()) {
    getIt.registerLazySingleton<GatewayConnectionRepository>(
      GatewayConnectionRepository.new,
    );
  }

  if (!getIt.isRegistered<GatewayConnectionBloc>()) {
    final bloc = GatewayConnectionBloc(
      config: getIt<GatewayConfig>(),
      repository: getIt<GatewayConnectionRepository>(),
    );
    getIt.registerSingleton<GatewayConnectionBloc>(bloc);
    bloc.add(const GatewayConnectionRequested());
  }
}

GatewayConfig _buildGatewayConfig() {
  final dynamic rawGateway = AppConstants.config('backend.gateway');
  if (rawGateway is Map<String, dynamic>) {
    return GatewayConfig.fromJson(rawGateway);
  }
  if (rawGateway is Map) {
    return GatewayConfig.fromJson(
      rawGateway.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return GatewayConfig();
}
