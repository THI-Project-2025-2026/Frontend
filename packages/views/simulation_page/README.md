# views/simulation_page package

Owns the acoustic simulation grid, related blocs, math utilities, and widgets.

## Adding new code
1. Move bloc logic into `lib/src/bloc/`, math helpers into `lib/src/math/`, and widgets into `lib/src/view/` or `widgets/`.
2. Re-export only the public screen widget(s) and bloc interfaces from `lib/simulation_page.dart`.
3. Depend solely on `flutter`, `flutter_bloc`, `core_ui`, `l10n_service`, and reusable `features/*` packages.
4. Heavy computation helpers should remain internal; expose simple methods or inherited widgets for consumers.

## Notes
- Delete the placeholder export once the real simulation feature files are migrated.
- Consider adding unit tests for acoustic math once extracted.
