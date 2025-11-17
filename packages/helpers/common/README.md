# helpers/common package

Pure Dart helpers that remain stateless, deterministic, and Flutter-free.

## Adding new code
1. Implement functions/classes under `lib/src/` and keep them side-effect free.
2. Re-export only the helpers you want consumers to use from `lib/common_helpers.dart`.
3. Avoid importing Flutter, `get_it`, or any UI-specific packages—stick to Dart SDK (and optional `meta`).
4. Add unit tests under `test/` once helpers exist; rely on the `test` package rather than Flutter test harnesses.

## Notes
- This package currently exports a placeholder; remove it when moving real helpers here.
