# core/ui package

Shared Sonalyze widgets (buttons, surfaces, accordions) live here so every feature can reuse the same look & feel.

## Adding new code
1. Create your widgets under `lib/src/` (e.g. `lib/src/buttons/sonalyze_button.dart`).
2. Export the public widgets via `lib/core_ui.dart` so consumers can import `package:core_ui/core_ui.dart` only.
3. Keep dependencies limited to Flutter, `l10n_service`, and lightweight utility packages; never import other feature packages directly.
4. Hide implementation details (themes, helpers) inside `lib/src/` and only surface stable APIs from the barrel file.

## Notes
- Default gradients/borders leverage `AppConstants` from `l10n_service`; extend that package with new theme keys before wiring them into widgets here.
