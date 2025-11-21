# Sonalyze Package Workspace

This workspace evolves the app into independently buildable packages grouped by responsibility.

## Folder groups
- `packages/core/`: shared UI and foundational building blocks that any feature can reuse.
- `packages/services/`: cross-cutting services (configuration, localization, data sources) that expose plain APIs and blocs.
- `packages/views/`: end-user screens bundling blocs, routing, and local models.
- `packages/features/`: reusable complex UI widgets (e.g., embedded web views) that higher-level views can import.
- `packages/helpers/`: future stateless, pure-Dart helpers with zero Flutter or DI coupling.

## Planned packages and rules
| Package path | Purpose | Allowed dependencies | Notes |
| --- | --- | --- | --- |
| `packages/core/ui` | Houses reusable Sonalyze widgets (buttons, surfaces, accordions) and exposes them via `lib/core_ui.dart`. | `flutter`, `meta`, design-token packages; no feature/service imports. | Widgets read colors/text through constructor params; no global lookups. |
| `packages/services/l10n` | Combines localization config, JSON parsing, `AppConstants`, and the JSON hot reload bloc behind `lib/l10n_service.dart`. | `flutter`, `flutter_bloc`, `path`, file I/O libs. | Owns JSON assets under `assets/` and re-exports only stable APIs; consumers avoid touching internals. |
| `packages/views/landing_page` | Landing page screen plus bloc, widgets, and demo data. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`, `features/*`. | Must not import other view packages; expose `LandingPageScreen` + bloc via barrel file. |
| `packages/views/measurement_page` | Measurement experience UI and bloc simulation logic. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`, `features/*`. | Same independence rules as other views. |
| `packages/views/simulation_page` | Simulation grid, math triggers, and blocs. | `flutter`, `flutter_bloc`, `core/ui`, `services/l10n`, `features/*`. | Heavy logic stays internal under `lib/src/`. |
| `packages/features/sonalyze_webview` | Reusable WebView widget that renders inline HTML/JS/CSS via `flutter_inappwebview`. | `flutter`, `flutter_inappwebview`. | Throws `UnsupportedError` on Linux; views embed it through the barrel export. |
| `packages/helpers/common` | (Future) stateless helpers/utilities shared by packages. | Pure Dart SDK. | No Flutter or `get_it`; functions stay deterministic. |

### lib vs lib/src convention
Every package must:
1. Place implementation files under `lib/src/`.
2. Re-export the public API surface from `lib/<package_name>.dart` (or similarly named barrel file).
3. Avoid importing another package's `lib/src` directly; all cross-package access goes through the barrel exports.

These rules ensure each package stays independently analyzable, and Melos can enforce boundaries once the workspace is fully wired.
