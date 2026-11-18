## 3.0.0 (unreleased)

Applies to `absmartly_dart` and `absmartly_sdk`.

### BREAKING
- **Minimum Dart 3.4.0 / Flutter 3.22.0.** The package constraints said Dart 2.18.6, but the dependencies (`crypto ^3.0.6`) already required Dart 3.4, so older SDKs could not resolve them.
- **Unit UIDs keep their type.** `setUnit`/`setUnits` on `Context` and `ContextConfig` accept a `String` or a number (`Object`), and `getUnit`/`getUnits` return the value exactly as it was set (`Object?`, `Map<String, Object>`), as in the JavaScript SDK. A numeric UID is hashed after rounding to a whole number, like JavaScript's `toFixed(0)` (so `125.75` is hashed as `"126"`). Code that reads units as `String` must cast or convert them (see "Migrating to 3.0.0" in the README).
- `track(name, null)` records `properties: null` in the goal event and the publish payload, instead of `{}`.
- `ContextEventHandler` renamed to `ContextPublisher` (`setContextPublisher` added).
- `EventType.close` is replaced by `EventType.finalize`; event loggers that switch on `close` must handle `finalize`.
- Deep imports of `package:absmartly_sdk/<file>.dart` no longer resolve; import `package:absmartly_sdk/absmartly_sdk.dart` (Flutter) or `package:absmartly_dart/absmartly_dart.dart` (pure Dart).
- **Unit UIDs with characters outside the Basic Multilingual Plane (emoji and other astral characters) are now hashed from their correct UTF-8 bytes**, as in every other ABsmartly SDK and the collector. Units whose UID contains such a character move to the variant the other SDKs already gave them, and get a new exposure.
- **Audiences are re-evaluated when attributes change.** A `setAttribute` after a treatment was read re-checks the experiment's audience (cross-SDK behaviour). A unit whose match flips is re-assigned on its next read and exposed again: with `audienceStrict` it moves between control and its randomised variant; without it, it keeps its variant and only the `audienceMismatch` flag of the new exposure changes.
- JSON expr `in` operator is haystack-first (CONTAINS alias added); `eq(null, null)` returns null.
- Read methods (treatment, peek, variable value, variable keys, custom fields) now throw "ABsmartly Context is not yet ready." before the context is ready, and "ABsmartly Context is finalized." after finalize, instead of returning defaults. `experiments()` only requires the context to be ready. A context whose load failed is ready and returns control/default values.

### Changed
- `X-Agent` is now `absmartly-dart-sdk/<version>` (was `absmartly-dart-sdk`). The collector stores it as the exposure's `agent`, so exports and dashboards that filter on `agent = 'absmartly-dart-sdk'` must match the new value.
- Every exposure now carries `ruleOverride` in the publish payload: `true` for a variant chosen by an assignment rule, otherwise `false`, as the JavaScript SDK sends it.
- The `Treatment`, `TreatmentBuilder`, `TreatmentSwitch` and `VariableValue` widgets read a failed context through the SDK (control/default values) instead of skipping it.
- **Audiences now always evaluate `application` and `environment`.** The application and environment names from the client config are placed in the attribute map that audience filters read, always on (no opt-in). User-set attributes of the same name still win, including when set after the context is created. These values are not added to the publish payload (the collector already attaches them server-side), and no `app_version`/`application_version` attribute is injected. **This changes assignment for running experiments:** a unit whose experiment has Audience enforced (`audienceStrict`) and an `environment`/`application` condition currently gets variant 0 (control) on every evaluation — those experiments are broken today. After upgrading, that unit is randomised normally.
- **Flutter web (dart2js) assigns variants as the VM and the other SDKs do.** The MurmurHash3 multiply and rotate lost low bits when compiled to JavaScript, so web users could get different variants than on mobile, and in 3.0.0 a different holdout arm. VM results are unchanged.

### Added
- **Holdouts.** Experiments covered by a holdout (the payload's top-level `holdouts` and each experiment's `holdoutIds`) are resolved as in the JavaScript SDK. A held-out unit gets variant 0 and no exposure for the covered experiment, and each holdout publishes its own exposure once per unit type. 2-arm and 3-arm holdouts are supported; the arm count comes from the holdout's split. `setOverride` and a matching assignment rule win over a holdout. A variable key that a holdout covers through any of its experiments is read as in the JavaScript SDK: every experiment checked is exposed, only one defining the key wins, and otherwise the first held-out experiment's control value applies. Keys no holdout covers read as before. A holdout id or holdout integer field outside ±(2^53 − 1) is dropped like any other malformed value. Payloads without holdouts publish the same bytes as before and never resolve a holdout; a cached treatment read adds one reference comparison and a variable read one emptiness check.
- `ContextHoldout` model, `ContextData.holdouts`, `Experiment.holdoutIds` and `Experiment.holdoutType`. The new `ContextData` and `Experiment` members are extension members and optional named constructor parameters, so existing classes that implement either model keep compiling. The SDK's own classes keep these values in fields; on a custom class that implements `ContextData` or `Experiment` they are attached to the instance and do not survive an isolate copy, so such a class must not be sent to another isolate with holdouts set.
- **Assignment rules.** An experiment's `assignmentRules` are evaluated in order; the first rule whose environments and conditions match decides the variant. An `assign` rule gives a fixed variant and a `split` rule (`"20/30/50"`) distributes units across the variants, hashing the unit with the experiment's seed. A matching rule wins over audiences, `audienceStrict`, traffic eligibility, full-on and custom assignments; only `setOverride` beats it. Its exposures carry `ruleOverride: true` and `assigned: false`. A split rule matched before its unit is set gives the experiment's no-unit result and is re-resolved once the unit is set, unless already exposed. Malformed rules are skipped; a split whose value count differs from the variant count, or an out-of-range assign variant, falls back to normal assignment.
- `Experiment.assignmentRules` and `Exposure.ruleOverride` wire-model fields (optional named constructor parameters). A class that `implements` either model must add the field.
- `semver_eq`, `semver_gt`, `semver_gte`, `semver_lt` and `semver_lte` JSON expression operators. A number operand is compared in the JavaScript SDK's string form (`toFixed(15)` without trailing zeros, exponent notation from `1e21`), independent of the locale.
- `ClientConfig.applicationVersion` (`setApplicationVersion`/`getApplicationVersion`, and the `applicationVersion` key of `createFromProperties`). `X-Application-Version` carries it, trimmed, only when it is a whole number of at most 18 digits, otherwise `0`, since the collector reads the header as a 64-bit integer. The value is never added to the attributes audiences evaluate or to the publish payload.
- `Client.getApplication()`, `getEnvironment()`, `getApplicationVersion()`, `getAgent()`, `getAgentName()` and `getAgentVersion()`. These and `ClientConfig.setApplicationVersion` are extension methods, so existing classes that implement `Client` or `ClientConfig` keep compiling.
- `finalize`/`isFinalized`/`isFinalizing` aliases, custom field support (`customFieldKeys`/`Value`/`ValueType`), `readyError`.
- Named-parameter factory constructors for config classes.

### Fixed
- Assignment cache preserved on refresh; publish error handling; UTF-8 encoding of astral characters in unit hashing.
- Integer split weights accepted when deserializing context data; stale async guards and provider `didUpdateWidget`.

## 1.0.0

First Flutter SDK Version
