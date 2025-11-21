# views/measurement_page package

Encapsulates the measurement lobby simulation experience (screens, blocs, demo telemetry).

## Adding new code
1. Relocate bloc, state, and model files into `lib/src/bloc/` (or similar) and UI under `lib/src/view/` / `widgets/`.
2. Export only public widgets and bloc APIs from `lib/measurement_page.dart`.
3. Keep dependencies limited to `flutter`, `flutter_bloc`, `core_ui`, `l10n_service`, and reusable `features/*` packages.
4. Do not access other view packages; share reusable pieces via `core`/`services` packages or promote them into `packages/features`.

## Notes
- Placeholder files should be removed once the actual measurement feature is moved over.
- Add targeted tests per bloc/widget when functionality stabilizes.
