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
  GatewayConfig config;
  
  if (rawGateway is Map<String, dynamic>) {
    config = GatewayConfig.fromJson(rawGateway);
  } else if (rawGateway is Map) {
    config = GatewayConfig.fromJson(
      rawGateway.map((key, value) => MapEntry(key.toString(), value)),
    );
  } else {
    config = GatewayConfig();
  }

  // For web builds, use secure WebSocket through nginx proxy
  if (kIsWeb) {
    return GatewayConfig(
      scheme: 'wss',
      host: Uri.base.host, // Use current domain (sonalyze.de)
      port: null, // No explicit port = uses default HTTPS port (443)
      path: '/ws',
      deviceId: config.deviceId,
    );
  }

  return config;
}
