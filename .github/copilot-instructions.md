# Sonalyze Frontend Guidance
**Project Snapshot**
- Flutter app focused on landing, measurement, and simulation experiences under `lib/views/*`, with assets driven by JSON.
- State management uses `flutter_bloc`; each page has its own bloc event/state trio in `lib/blocs/<feature>/`.
- Full directory overview and ownership notes live in `README_Projektstruktur.md`; keep that document current when you add or move files.
**App Boot & Configuration**
- `lib/main.dart` calls `AppConstants.initialize()` before `runApp` to preload configuration, theme, and translation JSON.
- Routes map `/`, `/simulation`, `/measurement`; keep `LandingPageScreen.routeName` constants in sync when adding navigation.
**Design Tokens & Copy**
- JSON in `lib/l10n/{configuration,themes,translations}/` feeds `AppConstants`; use `AppConstants.translation(key)` / `getThemeColor(key)` when wiring UI.
- `JsonParser` merges files on import; missing keys log warnings and return empty strings or transparent colors, so guard for fallbacks before surfacing to users.
**Hot Reload Helpers**
- `lib/blocs/json_hot_reload/` offers `JsonHotReloadBloc` that polls the active config/theme/translation files on desktop; web builds skip file watching via `kIsWeb`.
- Fire `StartFileWatching` once `AppConstants.initialize()` completes during dev to hot-reload JSON; use `ReloadTheme` / `ReloadLanguage` events for manual refreshes.
**Shared UI**
- `lib/utilities/ui/common/` holds `SonalyzeSurface`, `SonalyzeButton`, and accordion tiles—reuse them instead of ad-hoc `Container`/`TextButton` setups for consistent styling.
- Gradients and color palettes come from theme keys like `landing_page.feature_card_gradients.*`; introduce new keys in JSON before referencing them in widgets.
**Landing Page**
- `LandingPageBloc` seeds demo data (`LandingPageFeature.demoFeatures`) and rotates the active feature every 8s via a `Timer`; cancel timers in overrides if you extend bloc lifecycles.
- Widgets fetch copy through `_tr(...)`; add new text to `lib/l10n/translations/us.json` following existing key naming.
**Measurement Page**
- `MeasurementPageBloc` simulates lobby activity with `_telemetryTimer` and random metrics; apply immutable updates via `copyWith` to keep UI rebuilds predictable.
- Actions like `MeasurementDeviceDemoJoined`/`Left` depend on `MeasurementPageState.initial()` defaults—update that factory when changing roles, steps, or demo devices.
**Simulation Page**
- `SimulationPageBloc` recalculates acoustic metrics using `SimulationAcousticMath.compute*` whenever room dimensions or furniture events fire.
- The grid uses `SimulationPageState.gridSize = 8`; respect `selectedFurnitureKind` when adding gestures so taps continue to toggle placement/removal correctly.
**Testing & Tooling**
- `test/widget_test.dart` runs `AppConstants.initialize()` in `setUpAll`; replicate that pattern for new widget tests interacting with themed resources.
- Typical commands: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d <device>` from repo root; desktop builds pick up JSON edits live, web targets require a restart.
