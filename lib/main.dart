import 'package:flutter/material.dart';
import 'package:l10n_service/l10n_service.dart';
import 'package:sonalyze_frontend/views/landing_page/landing_page.dart';
import 'package:sonalyze_frontend/views/measurement_page/measurement_page.dart';
import 'package:sonalyze_frontend/views/simulation_page/simulation_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConstants.initialize();
  runApp(const SonalyzeApp());
}

class SonalyzeApp extends StatelessWidget {
  const SonalyzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeName =
        (AppConstants.config('defaultTheme') as String?)?.toLowerCase() ??
        'dark';
    final brightness = themeName == 'light'
        ? Brightness.light
        : Brightness.dark;
    final colorScheme = _buildColorScheme(brightness);

    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return MaterialApp(
      title: 'sonalyze',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: AppConstants.getThemeColor('app.background'),
        textTheme: baseTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: baseTextTheme.labelLarge,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppConstants.getThemeColor(
              'landing_page.hero_primary_button_background',
            ),
            foregroundColor: AppConstants.getThemeColor(
              'landing_page.hero_primary_button_text',
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConstants.getThemeColor(
              'landing_page.hero_secondary_button_text',
            ),
            side: BorderSide(
              color: AppConstants.getThemeColor(
                'landing_page.hero_secondary_button_border',
              ),
            ),
          ),
        ),
      ),
      onGenerateRoute: _onGenerateRoute,
      initialRoute: LandingPageScreen.routeName,
    );
  }
}

Route<dynamic> _onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case LandingPageScreen.routeName:
      return MaterialPageRoute<void>(
        builder: (_) => const LandingPageScreen(),
        settings: settings,
      );
    case SimulationPageScreen.routeName:
      return MaterialPageRoute<void>(
        builder: (_) => const SimulationPageScreen(),
        settings: settings,
      );
    case MeasurementPageScreen.routeName:
      return MaterialPageRoute<void>(
        builder: (_) => const MeasurementPageScreen(),
        settings: settings,
      );
    default:
      return MaterialPageRoute<void>(
        builder: (_) => const LandingPageScreen(),
        settings: settings,
      );
  }
}

ColorScheme _buildColorScheme(Brightness brightness) {
  final base = brightness == Brightness.dark
      ? ColorScheme.dark(
          primary: AppConstants.getThemeColor('app.primary'),
          onPrimary: AppConstants.getThemeColor('app.on_primary'),
          secondary: AppConstants.getThemeColor('app.secondary'),
          onSecondary: AppConstants.getThemeColor('app.on_secondary'),
          surface: AppConstants.getThemeColor('app.surface'),
          onSurface: AppConstants.getThemeColor('app.on_surface'),
          error: AppConstants.getThemeColor('app.error'),
          onError: AppConstants.getThemeColor('app.on_error'),
        )
      : ColorScheme.light(
          primary: AppConstants.getThemeColor('app.primary'),
          onPrimary: AppConstants.getThemeColor('app.on_primary'),
          secondary: AppConstants.getThemeColor('app.secondary'),
          onSecondary: AppConstants.getThemeColor('app.on_secondary'),
          surface: AppConstants.getThemeColor('app.surface'),
          onSurface: AppConstants.getThemeColor('app.on_surface'),
          error: AppConstants.getThemeColor('app.error'),
          onError: AppConstants.getThemeColor('app.on_error'),
        );
  return base;
}
