# helpers/common package

Pure Dart helpers that remain stateless, deterministic, and Flutter-free.

## Available helpers
- `formatNumber` – converts numeric values to trimmed strings for UI labels.
- `roundToDigits` – rounds a double to a configurable number of fraction digits without string parsing.

## Adding new code
1. Implement functions/classes under `lib/src/` and keep them side-effect free.
2. Re-export only the helpers you want consumers to use from `lib/common_helpers.dart`.
3. Avoid importing Flutter, `get_it`, or any UI-specific packages—stick to Dart SDK (and optional `meta`).
4. Add unit tests under `test/` once helpers exist; rely on the `test` package rather than Flutter test harnesses.

## Notes
- Keep helpers dependency-free (Dart SDK only) to stay lightweight and testable.
