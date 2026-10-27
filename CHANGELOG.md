## 3.0.0 (unreleased)

Applies to `absmartly_dart` and `absmartly_sdk`.

### BREAKING
- **Unit UIDs keep their type.** `setUnit`/`setUnits` on `Context` and `ContextConfig` accept a `String` or a number (`Object`), and `getUnit`/`getUnits` return the value exactly as it was set (`Object?`, `Map<String, Object>`), as in the JavaScript SDK. A numeric UID is hashed after rounding to a whole number, like JavaScript's `toFixed(0)` (so `125.75` is hashed as `"126"`). Code that reads units as `String` must cast or convert them (see "Migrating to 3.0.0" in the README).
- `track(name, null)` records `properties: null` in the goal event and the publish payload, instead of `{}`.
- `ContextEventHandler` renamed to `ContextPublisher` (`setContextPublisher` added).
- JSON expr `in` operator is haystack-first (CONTAINS alias added); `eq(null, null)` returns null.
- Read methods (treatment, peek, variable value, variable keys, custom fields) now throw "ABsmartly Context is not yet ready." before the context is ready, and "ABsmartly Context is finalized." after finalize, instead of returning defaults. `experiments()` only requires the context to be ready. A context whose load failed is ready and returns control/default values.

### Changed
- The `Treatment`, `TreatmentBuilder`, `TreatmentSwitch` and `VariableValue` widgets read a failed context through the SDK (control/default values) instead of skipping it.

### Added
- `finalize`/`isFinalized`/`isFinalizing` aliases, custom field support (`customFieldKeys`/`Value`/`ValueType`), `readyError`.
- Named-parameter factory constructors for config classes.

### Fixed
- Assignment cache preserved on refresh; publish error handling; UTF-8 encoding of astral characters in unit hashing.
- Integer split weights accepted when deserializing context data; stale async guards and provider `didUpdateWidget`.

## 1.0.0

First Flutter SDK Version
