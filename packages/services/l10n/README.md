# services/l10n package

Merges localization assets, `AppConstants`, the JSON parser, and the JSON hot reload bloc into a single service API for the rest of the workspace.

## Adding new code
1. Place implementations under `lib/src/` (e.g. `lib/src/app_constants.dart`, `lib/src/json_hot_reload/`).
2. Re-export only the stable API surface from `lib/l10n_service.dart` (e.g. `AppConstants`, bloc/event/state classes, helpers).
3. Store JSON assets under `assets/` and register them in this package's `pubspec.yaml` once moved.
4. Keep dependencies limited to Flutter, `flutter_bloc`, file/IO packages, and any future service-specific utilities.

## Notes
- Consumers should never import `lib/src/*` directly; they must rely on the barrel file.
- The placeholder export can be removed once the real implementation lands.
