## 3.0.0 (unreleased)

Applies to `absmartly_dart` and `absmartly_sdk`.

### BREAKING
- **Unit UIDs keep their type.** `setUnit`/`setUnits` on `Context` and `ContextConfig` accept a `String` or a number (`Object`), and `getUnit`/`getUnits` return the value exactly as it was set (`Object?`, `Map<String, Object>`), as in the JavaScript SDK. A numeric UID is hashed after rounding to a whole number, like JavaScript's `toFixed(0)` (so `125.75` is hashed as `"126"`). Code that reads units as `String` must cast or convert them (see "Migrating to 3.0.0" in the README).
- `track(name, null)` records `properties: null` in the goal event and the publish payload, instead of `{}`.
- `ContextEventHandler` renamed to `ContextPublisher` (`setContextPublisher` added).
- JSON expr `in` operator is haystack-first (CONTAINS alias added); `eq(null, null)` returns null.
- Read methods (treatment, peek, variable value, variable keys, custom fields) now throw "ABsmartly Context is not yet ready." before the context is ready, and "ABsmartly Context is finalized." after finalize, instead of returning defaults. `experiments()` only requires the context to be ready. A context whose load failed is ready and returns control/default values.

### Changed
- `X-Agent` is now `absmartly-dart-sdk/<version>` (was `absmartly-dart-sdk`).
- The `Treatment`, `TreatmentBuilder`, `TreatmentSwitch` and `VariableValue` widgets read a failed context through the SDK (control/default values) instead of skipping it.
- **Audiences now always evaluate `application` and `environment`.** The application and environment names from the client config are placed in the attribute map that audience filters read, always on (no opt-in). User-set attributes of the same name still win, including when set after the context is created. These values are not added to the publish payload (the collector already attaches them server-side), and no `app_version`/`application_version` attribute is injected. **This changes assignment for running experiments:** a unit whose experiment has Audience enforced (`audienceStrict`) and an `environment`/`application` condition currently gets variant 0 (control) on every evaluation — those experiments are broken today. After upgrading, that unit is randomised normally.

### Added
- **Assignment rules.** An experiment's `assignmentRules` are evaluated in order; the first rule whose environments and conditions match decides the variant. An `assign` rule gives a fixed variant and a `split` rule (`"20/30/50"`) distributes units across the variants, hashing the unit with the experiment's seed. A matching rule wins over audiences, `audienceStrict`, traffic eligibility, full-on and custom assignments; only `setOverride` beats it. Its exposures carry `ruleOverride: true` and `assigned: false`. A split rule matched before its unit is set gives the experiment's no-unit result and is re-resolved once the unit is set, unless already exposed. Malformed rules are skipped; a split whose value count differs from the variant count, or an out-of-range assign variant, falls back to normal assignment.
- `semver_eq`, `semver_gt`, `semver_gte`, `semver_lt` and `semver_lte` JSON expression operators.
- `ClientConfig.applicationVersion`. `X-Application-Version` carries it only when it is a whole number of at most 18 digits, otherwise `0`.
- `finalize`/`isFinalized`/`isFinalizing` aliases, custom field support (`customFieldKeys`/`Value`/`ValueType`), `readyError`.
- Named-parameter factory constructors for config classes.

### Fixed
- Assignment cache preserved on refresh; publish error handling; UTF-8 encoding of astral characters in unit hashing.
- Integer split weights accepted when deserializing context data; stale async guards and provider `didUpdateWidget`.

## 1.0.0

First Flutter SDK Version
