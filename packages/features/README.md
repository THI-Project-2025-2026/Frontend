# packages/features

Reusable complex widgets (e.g., embedded WebViews) that can be consumed by multiple view packages live here. Each sub-package must:

1. Keep implementation code under `lib/src/**` and re-export a stable API via `lib/<package_name>.dart`.
2. Avoid importing `packages/views/**` directly—features stay view-agnostic.
3. Depend only on allowed groups from `import_rules.yaml` (typically `core_ui`, services, and helpers).
4. Provide README + tests describing how consumers should configure and integrate the widget.

New features should be added as Melos workspace members (update the root `pubspec.yaml` `workspace:` list and `import_rules.yaml`) and bootstrapped via `melos run bootstrap`.
