# Sonalyze Frontend

Flutter workspace for the Sonalyze app plus its feature/service packages managed with [Melos](https://melos.invertase.dev/).

## Requirements

- Flutter 3.22+ (channel stable)
- Dart SDK aligned with the Flutter version
- Melos installed once via `dart pub global activate melos`

## Initial Setup

1. Fetch root-level dependencies so custom tooling (e.g., linters) is available.

```bash
flutter pub get
```

2. Bootstrap every workspace package via Melos to wire path dependencies and install per-package pubs:

```bash
melos run bootstrap
```

## Workspace Overview

- Application entry point lives in `lib/` (main app + DI glue).
- View/feature/service/helper code resides in `packages/**`, each as its own publishable package.
- Cross-package imports are governed by `import_rules.yaml`; the `lint:imports` task enforces it.

## Melos Commands

- `melos run bootstrap` — runs `melos bootstrap` to install/link every package.
- `melos run analyze` — executes `flutter analyze --no-pub` per package via `tool/custom_analyze.dart` with colored summaries.
- `melos run lint:imports` — launches `tool/lint_imports.dart` to ensure only allowed workspace packages are imported (configured in `import_rules.yaml`).
- `melos run test` — runs `flutter test` for packages that expose a `test/` directory.
- `melos run format` — formats each package’s `lib/` directory with `dart format`.

> Tip: wire `analyze`, `lint:imports`, and `test` into CI to catch violations before merging.

## Updating Import Rules

- Every workspace package (app + `packages/**`) must have an entry in `import_rules.yaml` describing which other internal packages it may import.
- Use the predefined group aliases `services`, `helpers`, `views`, `features`, and `core` inside `allowed_packages` when you want to allow an entire folder of packages (they expand automatically as new packages are added). Mix them with specific package names (e.g. `l10n_service`) when you need tighter control.
- When adding or moving packages, update both `pubspec.yaml` → `workspace:` and `import_rules.yaml`; `melos run lint:imports` fails if a package is missing or violates the allow-list.
