# services/l10n package

Merges localization assets, `AppConstants`, the JSON parser, and the JSON hot reload bloc into a single service API for the rest of the workspace.

## Adding new code
1. Place implementations under `lib/src/` (e.g. `lib/src/app_constants.dart`, `lib/src/json_hot_reload/`).
2. Re-export only the stable API surface from `lib/l10n_service.dart` (e.g. `AppConstants`, bloc/event/state classes, helpers).
3. Store JSON assets under `assets/` and keep `pubspec.yaml` in sync so Flutter bundles them for dependents.
4. Keep dependencies limited to Flutter, `flutter_bloc`, `meta`, `path`, and any future service-specific utilities.

## Notes
- Consumers should never import `lib/src/*` directly; they must rely on the barrel file.
- Use `L10nAssetPaths` whenever you need both a dev filesystem path and an asset bundle path for the same JSON file.
