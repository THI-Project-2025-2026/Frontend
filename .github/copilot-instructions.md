# Sonalyze Frontend – AI Coding Guide

- **Workspace Setup**
  - Use Flutter 3.22+ with Melos (`melos.yaml`). Bootstrap once via:
    ```bash
    flutter pub get
    melos run bootstrap
    ```
  - Preferred automation commands (wired in Melos scripts):
    - `melos run analyze` → `tool/custom_analyze.dart` runs `flutter analyze --no-pub` per package and fails on the first issue.
    - `melos run lint:imports` → `tool/lint_imports.dart` enforces `import_rules.yaml` (update this file whenever new packages/graphs change).
    - `melos run test` only exercises packages that expose a `test/` directory; author package-level tests to get coverage.
    - `melos run format` formats each package’s `lib/`.

- **Architecture Snapshot**
  - Root `lib/` holds only the Flutter entry (`lib/main.dart`) plus DI glue (`lib/di/injector.dart`). Everything else lives in packages under `packages/{core,services,views,features,helpers}`.
  - `packages/services/l10n` owns configuration/theme/translation JSON plus `AppConstants`, `JsonParser`, and `JsonHotReloadBloc`. All UI pulls colors/text through this package; never read JSON files from other packages.
  - Each view (e.g., `packages/views/measurement_page`) is a full Flutter package exposing a single barrel file (`lib/<view>.dart`) that re-exports its screen and bloc. Implementation stays in `lib/src/**`.
  - Shared widgets live in `packages/core/ui` (e.g., `SonalyzeSurface`, `SonalyzeButton`); stateless helpers go to `packages/helpers/common` and must remain pure Dart.

- **Dependency Boundaries**
  - Respect `import_rules.yaml`: the app may depend on `services`, `views`, and reusable `features`; views may depend on `core`, `services`, `helpers`, and complex widget features; complex widget features depend on `core`, `services`, `helpers`, but never on views. `core_ui` can only use helpers+l10n; helpers stay dependency-free. Run `melos run lint:imports` after touching imports.
  - Packages must follow the `lib/` vs `lib/src/` convention—only expose APIs via barrel files (e.g., `packages/views/landing_page/lib/landing_page.dart`). Never import another package’s `lib/src` path.
  - When adding a package, update `pubspec.yaml` (workspace section) + `import_rules.yaml` and re-run `melos run bootstrap` to refresh path deps.

- **Localization, Themes, and Hot Reload**
  - `AppConstants.initialize()` loads config → themes → translations from `packages/services/l10n/assets/**`. Access them via `AppConstants.config('some.path')`, `AppConstants.getThemeColor(...)`, or `AppConstants.translation(...)` instead of hard-coded values.
  - Debug desktop builds auto-start `JsonHotReloadBloc` from `configureDependencies()` (`lib/di/injector.dart`), which polls the JSON files every 500 ms. Do not create extra watchers—extend the existing bloc events (`json_hot_reload_event.dart`) if new asset types need reloads.
  - Web builds cannot watch files (`dart:io` unavailable); guard any watcher-related logic behind `kIsWeb` as done in the service package.

- **View Patterns**
  - Screens expose a static `routeName` and wrap their UI with a `BlocProvider` (see `packages/views/measurement_page/lib/src/view/measurement_page_screen.dart`). Keep BLoC/event/state files under `lib/src/bloc/` and rebuild widgets via `BlocBuilder`.
  - Pull copy + colors through `AppConstants` helpers instead of embedding strings—e.g., `_tr('measurement_page.devices.title')`, `_themeColor('measurement_page.accent')`.
  - Use shared surfaces/buttons from `core_ui` to match Sonalyze styling; pass theme colors from l10n instead of looking up `Theme.of(context)` directly when the design tokens drive the values.
  - Prefer pure helpers from `common_helpers` (e.g., `formatNumber`, `roundToDigits`) for repeatable formatting logic.

- **DI & Global State**
  - `get_it` is configured once inside `configureDependencies()`; it registers `AppConstants` and a singleton `JsonHotReloadBloc`. Register new cross-feature services here and inject them downward—avoid calling `GetIt.instance` inside package internals unless absolutely needed.
  - `main.dart` builds `MaterialApp` using tokenized colors from `AppConstants` and wires routes via imported feature packages (`LandingPageScreen.routeName`, etc.). New routes must be exported from their feature package and added to `_onGenerateRoute` here.

- **Extending the Workspace**
  - New shared UI? Create components under `packages/core/ui/lib/src/...`, export via `lib/core_ui.dart`, and document usage in that package’s README.
  - New view (screen + bloc)? Scaffold under `packages/views/<name>/`, expose a barrel file, and update `import_rules.yaml`, `pubspec.yaml`, and `lib/main.dart` routing.
  - New complex widget feature? Scaffold under `packages/features/<name>/`, export it via a barrel file, and ensure views depend on it through the public API only.
  - New helper? Keep it deterministic inside `packages/helpers/common/lib/src/`, add unit tests, and expose it via the barrel file.
  - Asset or theme updates live exclusively in `packages/services/l10n/assets/**`; rerun the app (or rely on hot reload) once the watcher picks them up.

- **Before Sending PRs / Handing Off**
  - Run `melos run analyze`, `melos run lint:imports`, and (when applicable) `melos run test`. Fix all analyzer + import violations—they block CI.
  - Ensure new packages obey the documented dependency graph and that barrel exports hide implementation detail.
  - Keep this file in sync when workflows or package rules change so future AI agents stay productive.
