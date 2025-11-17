# features/landing_page package

Owns the landing page screen, its bloc, demo data, and supporting widgets.

## Adding new code
1. Move widgets, blocs, and models into `lib/src/` (organize by `bloc/`, `view/`, `widgets/`, etc.).
2. Export only the public screen + bloc API from `lib/landing_page.dart` (e.g. `LandingPageScreen`, bloc events/states).
3. Depend only on `flutter`, `flutter_bloc`, `core_ui`, and `l10n_service`; never import another feature package directly.
4. Keep timers or other lifecycle resources disposed within the package—callers should just use the exposed widgets/blocs.

## Notes
- Replace the placeholder export after migrating the real landing page files.
- Add widget or bloc tests inside `test/` once functionality is in place.
