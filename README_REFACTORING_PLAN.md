User: I want you to create a plan to refactor my entire codebase. Currently it has a layer-first ARchitecture, but I want you to transform it into a feature first architecture, where the packages are stored in a new folder called packages/ and are 100% independant. Here are the goals:
- I want to use Melos
- I want to use get_it
- each package should be 100% independant
- in packages there should be the following folders: features (for the views like measurement_page.dart), services (l10n), core (i.e. shared ui), helpers (stateless helper functions, do not have any yet)

Create a overview and step-by-step guide so that AI agents can complete that task

GitHub Copilot: Enable GPT-5.1 (Preview) for all clients
[object Object]

User: @agent Enable: "Enable GPT-5.1 (Preview) for all clients"

GitHub Copilot: 

User: @agent Try Again

GitHub Copilot: ## Plan: Refactor to Melos-Based Feature-First Packages

Transform the current single Flutter app into a Melos-managed workspace with multiple Dart/Flutter packages under `packages/`, structured by responsibility (`features`, `services`, `core`, `helpers`). Each package will be independently buildable/testable, wired together in the app via `get_it` for dependency injection. The refactor will be incremental: first introduce Melos, then carve out shared/core pieces, then feature packages, finally routing and DI wiring.

### Steps

1. **Introduce Melos workspace and top-level layout**
   1. Add a `melos.yaml` in the repo root configuring a workspace with `packages/*/*` as package locations (e.g. `packages/**`).
   2. Create folder groups under `packages/`: `packages/features/`, `packages/services/`, `packages/core/`, `packages/helpers/`.
   3. For each group, add placeholder README.md describing its purpose and independence rules (no cross-imports except via `pubspec` dependencies).

2. **Define target package structure and responsibilities**
   1. Decide on minimal package list:
      - `packages/core/ui` (shared widgets like `SonalyzeButton`, `SonalyzeSurface`),
      - `packages/services/l10n` (configuration, themes, translations, JSON loading),
      - `packages/features/landing_page`,
      - `packages/features/measurement_page`,
      - `packages/features/simulation_page`,
      - `packages/services/json_hot_reload` (file watching),
      - `packages/helpers/common` (future stateless helper functions).
   2. For each package, draft a mini-README: public API surface, allowed dependencies, forbidden coupling (e.g. features depend on services/core but not on each other).

3. **Create independent Dart/Flutter packages under `packages/`**
   1. For each planned package, scaffold a Dart or Flutter package:
      - Features → Flutter packages (they contain widgets and BLoCs),
      - Services/helpers/core → pure Dart unless they need Flutter types.
   2. In each package, add its own pubspec.yaml with:
      - A unique `name` and `version`,
      - Dependencies only on what’s needed (e.g., `flutter_bloc` for feature packages, `get_it` where DI will be registered),
      - A lib entry point file (`lib/<package_name>.dart`) exposing the public API.
   3. Ensure each package is buildable in isolation with `dart analyze` or `flutter test` from its directory (once code is moved).

4. **Extract `core` shared UI components**
   1. Move `lib/utilities/ui/common/*` into `packages/core/ui/lib/` under a suitable structure, e.g. `src/common/` and exports from `lib/core_ui.dart`.
   2. Update imports in the new package to be package-local (no references to `sonalyze_frontend/lib/...`).
   3. In the main app’s pubspec.yaml, add a path dependency on `packages/core/ui`.
   4. Update all references in `lib/views/*` to import from `package:core_ui/core_ui.dart` (or similar), ensuring no feature depends directly on the app package for these widgets.

5. **Extract localization and configuration as a `services/l10n` package**
   1. Move json_parser.dart, app_constants.dart, and the JSON files (`configuration`, `themes`, `translations`) into `packages/services/l10n/lib/` and `packages/services/l10n/assets/` respectively.
   2. Adjust `AppConstants` and `JsonParser` to not import from the main app; instead expose them as public API from `package:l10n/l10n.dart`.
   3. Configure the `l10n` package’s pubspec.yaml to include its JSON assets and any dependencies (`flutter`, `path`, etc.).
   4. In the root app, remove direct l10n and constants code; instead, add a path dependency on `services/l10n` and update `main.dart` (and others) to import `AppConstants` via `package:l10n/l10n.dart`.

6. **Extract `json_hot_reload` into a `services` or `helpers` package**
   1. Move `lib/blocs/json_hot_reload/*` to a new package (e.g. `packages/services/json_hot_reload/lib/`).
   2. Ensure its pubspec.yaml declares dependencies on `flutter_bloc` and on the `l10n` package if needed.
   3. From the main app (and any features using it), replace imports to refer to `package:json_hot_reload/json_hot_reload.dart`.

7. **Modularize feature BLoCs and views into feature packages**
   1. For each feature (landing, measurement, simulation):
      - Move its BLoC files from `lib/blocs/<feature>/` into the corresponding feature package under `lib/src/bloc/`.
      - Move its view file from `lib/views/<feature>/` into the same package under `lib/src/view/`.
   2. In each feature package, create a barrel file (e.g. `lib/landing_page.dart`) that exports the public screen widget and any public BLoCs/state types.
   3. Configure each feature package’s pubspec.yaml with:
      - Dependencies on `flutter`, `flutter_bloc`,
      - Dependencies on `core/ui`, `services/l10n`, `services/json_hot_reload` as needed,
      - No dependencies on other feature packages (to keep independence).
   4. In the app’s pubspec.yaml, add path dependencies on all feature packages and update `main.dart` to import routes from feature packages instead of `lib/views/...`.

8. **Introduce and wire `get_it` for dependency injection**
   1. Decide where the DI composition root lives: use the root app as the only place that wires everything.
   2. Add `get_it` as a dependency to the root app and any package that needs to *access* the locator (but avoid features registering global singletons themselves).
   3. Create a DI setup file in the app (e.g. `lib/di/injector.dart`) that:
      - Registers services from `services/l10n` (e.g. `AppConstants` or an abstraction),
      - Registers any other shared services or repositories (if added later).
   4. In feature packages, define abstractions (e.g. interfaces or typedefs) for dependencies they require (currently mostly `AppConstants`, maybe simulation math later), and retrieve them via `get_it` in widgets/BLoCs where needed.
   5. Update `main.dart` so that before `runApp`, the DI is configured, then pass any necessary references into `SonalyzeApp` if you want to avoid using `get_it` in the root widget.

9. **Rework app entry point and routing to use feature packages**
   1. Simplify main.dart so it:
      - Initializes DI (`get_it`), 
      - Initializes `AppConstants` via the `l10n` package,
      - Builds `MaterialApp` using theme data from `l10n` and shared `core/ui` resources if needed.
   2. Replace route references with the exported route names and page widgets from each feature package (e.g. `LandingPageScreen.routeName` imported from `package:landing_page/landing_page.dart`).
   3. Ensure `SonalyzeApp` only depends on feature packages and services via their public package APIs.

10. **Ensure package independence and update imports**
    1. Run `melos bootstrap` to link all path dependencies and generate a unified lockfile.
    2. Use `melos exec -- flutter analyze` (or equivalent) to analyze all packages; fix imports that still reference old paths under lib.
    3. Check that each package:
       - Has no relative imports into another package’s lib folder,
       - Only depends on others via pubspec.yaml and `package:` imports,
       - Compiles in isolation if you run `flutter analyze` or tests from its directory.
    4. Remove obsolete folders under the root lib (once all consumers are updated), leaving only app-specific glue code (`main.dart`, maybe `di/` or global app widgets).

11. **Integrate Melos workflows and documentation**
    1. Add Melos scripts in `melos.yaml` for common tasks:
       - Bootstrap, analyze, test, and format across all packages.
    2. Update root README.md and README_Projektstruktur.md:
       - Document the new `packages/` structure and naming,
       - Explain how to add new features/services/core modules,
       - Describe mandatory usage of `get_it` for shared services.
    3. Optionally add a short `CONTRIBUTING` section describing how AI agents should create new packages and wire them into Melos and DI.

12. **Optional: Add helpers package scaffolding for future stateless utilities**
    1. Create `packages/helpers/common` with a minimal Dart package and `lib/common_helpers.dart` exporting an empty `helpers` namespace for now.
    2. Put clear guidelines in the package README:
       - Stateless functions only,
       - No Flutter dependencies,
       - No access to `get_it` (pure functional).

### Further Considerations

1. Clarification: Should each feature package stay Flutter-only (widgets+BLoC) and push any domain logic into future dedicated `services` packages, or can they own simple domain logic?
2. Naming: Confirm naming conventions for packages (e.g. `sonalyze_core_ui` vs `core_ui`) and whether you prefer prefixes for all packages.
3. Testing: Decide whether to add per-package tests now (e.g. widget tests in feature packages, unit tests in services) or keep testing centralized until the refactor is stable.

User: json hot reload and l10n should be one package since the json loading is only relevant for the l10n. Also, make sure to use the flutter lib/ and lib/src/ convention where lib/ contains the "public interface" and lib/src/ the private logic behind it

GitHub Copilot: 

User: @agent Try Again

GitHub Copilot: 

User: @agent Try Again

GitHub Copilot: 

User: @agent Try Again

GitHub Copilot: 

User: @agent Try Again

GitHub Copilot: ## Plan: Melos Feature-First Refactor with `get_it` and Packages

Refactor the current layer-first Flutter app into a Melos workspace with independent packages under `packages/`. Each package will have its own pubspec.yaml, use the lib + `lib/src/` convention for public vs. private APIs, and communicate only through `package:` imports. `json_hot_reload` and `l10n` will be merged into a single service package. `get_it` will be used for dependency lookup at the app layer, keeping DI wiring centralized.

### Migration Steps

1. **Define target package layout and rules**
   1. Create `packages/features/`, `packages/services/`, `packages/core/`, `packages/helpers/` folders.
   2. Decide on packages:
      - `packages/core/ui` (shared widgets: `SonalyzeSurface`, `SonalyzeButton`, etc.).
      - `packages/services/l10n` (configuration, themes, translations, `AppConstants`, `JsonParser`, `JsonHotReloadBloc`).
      - `packages/features/landing_page`.
      - `packages/features/measurement_page`.
      - `packages/features/simulation_page`.
      - `packages/helpers/common` (future stateless helpers).
   3. For each package, document:
      - Its purpose and allowed dependencies.
      - That it must expose only via `lib/<package_name>.dart` (public) and put internals in `lib/src/`.

2. **Introduce Melos workspace at root**
   1. Add `melos.yaml` with:
      - `packages: ["packages/**"]`.
      - Scripts for `bootstrap`, `analyze`, test, `format`.
   2. Run `melos bootstrap` after initial scaffolding to ensure workspace wiring.
   3. Update README_Projektstruktur.md to describe the workspace and `packages/` layout.

3. **Scaffold empty packages with lib/`src` convention**
   1. For each planned package:
      - For UI and features: create Flutter packages (they depend on `flutter`).
      - For services/helpers: create Dart or Flutter packages depending on whether they need Flutter.
   2. In each package:
      - Create `lib/<package_name>.dart` as the barrel/public interface.
      - Create `lib/src/` and place internal files there (even if initially empty).
   3. Add minimal README.md in each package explaining:
      - How to add new code.
      - That all new files go into `lib/src/` and are re-exported via the main `lib/<package_name>.dart` file.

4. **Create `services/l10n` package (merged l10n + json hot reload)**
   1. Move the following into `packages/services/l10n/lib/src/`:
      - json_parser.dart.
      - app_constants.dart.
      - `lib/blocs/json_hot_reload/*.dart`.
   2. Move JSON files into the package:
      - configuration → `packages/services/l10n/assets/configuration/`.
      - themes → `packages/services/l10n/assets/themes/`.
      - translations → `packages/services/l10n/assets/translations/`.
   3. In `packages/services/l10n/lib/l10n_service.dart` (or similar):
      - Export only the public API you want consumers to see: e.g. `AppConstants`, a `L10nService` abstraction, `JsonHotReloadBloc` and its events/states.
      - Keep internal utilities under `lib/src/` and re-export selectively.
   4. Configure `packages/services/l10n/pubspec.yaml`:
      - Add dependencies: `flutter`, `flutter_bloc`, `path` (if used), etc.
      - Register JSON assets under `flutter: assets:` pointing to its `assets/` subfolders.
   5. Update main app and any other code to import from `package:l10n_service/l10n_service.dart` instead of `sonalyze_frontend/...`.
   6. Remove original constants and l10n folders once all references are updated.

5. **Create `core/ui` shared UI package**
   1. Move `lib/utilities/ui/common/*` into `packages/core/ui/lib/src/common/` and adjust imports to be local.
   2. In `packages/core/ui/lib/core_ui.dart`:
      - Export the shared widgets intended to be public.
   3. Configure `packages/core/ui/pubspec.yaml`:
      - Add `flutter` and any other UI-related dependencies.
   4. In features and app:
      - Replace old imports (`lib/utilities/ui/common/...`) with `package:core_ui/core_ui.dart`.
   5. Remove old common folder after all imports are migrated.

6. **Modularize feature code into feature packages**
   1. For each feature (landing, measurement, simulation):
      - Create a package in `packages/features/<feature_name>/`.
      - Move BLoCs from `lib/blocs/<feature_name>/` into `lib/src/bloc/` of that package.
      - Move the corresponding view from `lib/views/<feature_name>/<feature_name>.dart` into `lib/src/view/`.
   2. In each feature package’s main file (`lib/<feature_name>.dart`):
      - Export the main screen widget and any public-facing BLoC types.
      - Keep internal sub-widgets and utilities in `lib/src/` without re-export unless needed.
   3. Configure each feature package’s pubspec.yaml:
      - Dependencies: `flutter`, `flutter_bloc`, `core_ui`, `l10n_service` (for text and themes).
      - No direct dependencies on other features (to keep packages independent).
   4. In the app’s pubspec.yaml:
      - Add `path` dependencies for all feature packages.
   5. Update the app’s route setup in main.dart to import and use the `LandingPageScreen`, `MeasurementPageScreen`, `SimulationPageScreen` from their feature packages.

7. **Introduce `get_it` and define DI boundaries**
   1. Add `get_it` to the app’s pubspec.yaml (and only to packages that must resolve from it, not necessarily to all).
   2. Create `lib/di/injector.dart` in the main app:
      - Initialize a global `GetIt` instance (e.g. `final getIt = GetIt.instance;`).
      - Register services from `l10n_service` like `AppConstants`, `JsonHotReloadBloc`, and any future domain services.
   3. Decide usage style:
      - Prefer passing dependencies down via constructors for testability, but allow features to read from `get_it` for services when necessary.
   4. In feature packages:
      - Expose constructor parameters for services (e.g. `LandingPageScreen({required L10nService l10n})`), or, as an alternative:
      - Use `get_it` directly but hide it behind an abstraction if possible (e.g. `L10nProvider` using `getIt` internally).
   5. Update `main.dart`:
      - Before `runApp`, call the DI setup.
      - Ensure `AppConstants.initialize()` is invoked via `l10n_service` (could be called as part of DI registration or explicitly before DI registration).

8. **Prepare `helpers/common` package for stateless utilities**
   1. Create `packages/helpers/common` with:
      - `lib/common_helpers.dart` as the public entry file.
      - `lib/src/` for future helper implementations.
   2. Document constraints:
      - No Flutter dependency (pure Dart).
      - No `get_it` references inside helpers (remain stateless and pure).
   3. Keep it initially empty or move any suitable reusable stateless functions into `lib/src/` and re-export them.

9. **Clean up the main app package**
   1. After migrating:
      - Restrict lib in the app to:
        - `main.dart` (entry),
        - `di/` for dependency setup,
        - Optional app-level widgets (e.g. `SonalyzeApp`).
   2. Remove old `blocs/`, `views/`, `utilities/`, `constants/`, `l10n/` from the app once confirmed that all imports point to packages.
   3. Update README_Projektstruktur.md to:
      - Reflect the new feature-first architecture.
      - Show how `packages/features`, `packages/services`, `packages/core`, and `packages/helpers` are structured.
      - Explain the lib vs `lib/src/` convention for all packages.

10. **Validate independence and Melos integration**
    1. Run analysis per package:
       - In each package directory: `flutter analyze` or `dart analyze` to confirm no invalid imports.
    2. From workspace root, run Melos commands:
       - `melos bootstrap` (ensure all path deps wired).
       - `melos exec -- flutter analyze` and `melos exec -- flutter test` (if tests exist).
    3. Check for:
       - No remaining relative imports across package boundaries.
       - Each package compiling and being usable independently.
    4. Fix any remaining references to old `sonalyze_frontend/lib/...` paths by pointing them to the appropriate package APIs.

### Further Considerations

1. Decide whether feature packages should use `get_it` directly or accept dependencies via constructors, with the app wiring them using DI; constructor-based approach improves testability.
2. Confirm naming conventions for package names (e.g. `sonalyze_core_ui`, `sonalyze_l10n`, `sonalyze_landing_page`) to keep them consistent and avoid collisions.
3. Once the structure is stable, consider adding minimal tests per package (e.g. widget tests for features, unit tests for `l10n` parsing) so future refactors can be validated by Melos test runs.