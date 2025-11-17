# Sonalyze Package Workspace

This workspace evolves the app into independently buildable packages grouped by responsibility.

## Folder groups
- `packages/core/`: shared UI and foundational building blocks that any feature can reuse.
- `packages/services/`: cross-cutting services (configuration, localization, data sources) that expose plain APIs and blocs.
- `packages/features/`: end-user features bundling screens, blocs, and local models.
- `packages/helpers/`: future stateless, pure-Dart helpers with zero Flutter or DI coupling.

## Planned packages and rules
| Package path | Purpose | Allowed dependencies | Notes |
| --- | --- | --- | --- |
| `packages/core/ui` | Houses reusable Sonalyze widgets (buttons, surfaces, accordions) and exposes them via `lib/core_ui.dart`. | `flutter`, `meta`, design-token packages; no feature/service imports. | Widgets read colors/text through constructor params; no global lookups. |
| `packages/services/l10n` | Combines localization config, JSON parsing, `AppConstants`, and the JSON hot reload bloc behind `lib/l10n_service.dart`. | `flutter`, `flutter_bloc`, `path`, file I/O libs. | Owns JSON assets under `assets/` and re-exports only stable APIs; consumers avoid touching internals. |
| `packages/features/landing_page` | Landing page screen plus bloc, widgets, and demo data. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`. | Must not import other feature packages; expose `LandingPageScreen` + bloc via barrel file. |
| `packages/features/measurement_page` | Measurement experience UI and bloc simulation logic. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`. | Same independence rules as other features. |
| `packages/features/simulation_page` | Simulation grid, math triggers, and blocs. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`. | Heavy logic stays internal under `lib/src/`. |
| `packages/helpers/common` | (Future) stateless helpers/utilities shared by packages. | Pure Dart SDK. | No Flutter or `get_it`; functions stay deterministic. |

### lib vs lib/src convention
Every package must:
1. Place implementation files under `lib/src/`.
2. Re-export the public API surface from `lib/<package_name>.dart` (or similarly named barrel file).
3. Avoid importing another package's `lib/src` directly; all cross-package access goes through the barrel exports.

These rules ensure each package stays independently analyzable, and Melos can enforce boundaries once the workspace is fully wired.
