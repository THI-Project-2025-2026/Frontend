# features/measurement_page package

Encapsulates the measurement lobby simulation experience (screens, blocs, demo telemetry).

## Adding new code
1. Relocate bloc, state, and model files into `lib/src/bloc/` (or similar) and UI under `lib/src/view/` / `widgets/`.
2. Export only public widgets and bloc APIs from `lib/measurement_page.dart`.
3. Keep dependencies limited to `flutter`, `flutter_bloc`, `core_ui`, and `l10n_service`.
4. Do not access other feature packages; share reusable pieces via `core`/`services` packages instead.

## Notes
- Placeholder files should be removed once the actual measurement feature is moved over.
- Add targeted tests per bloc/widget when functionality stabilizes.
