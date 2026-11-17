## 2.2.0

Applies to `absmartly_sdk` and to the new `absmartly_dart` package. Code written for `absmartly_sdk` 2.1.x keeps compiling and behaving as before; nothing has to change to upgrade. Breaking API changes are kept for the next major version.

### Added
- **`absmartly_dart`**, a pure Dart package with the SDK core and no Flutter dependency, for Dart CLI and server apps. `absmartly_sdk` depends on it and re-exports it, so `import 'package:absmartly_sdk/absmartly_sdk.dart'` and every 2.1 deep import (`package:absmartly_sdk/context.dart`, `.../client_config.dart`, `.../jsonexpr/operators/greater_then_operator.dart`, …) still resolve, with the same class names. `absmartly_sdk.dart` now also exports `ContextConfig`, `ClientConfig`, `ABSmartly`, `EventType`, the widgets below and the other public types, so the README example needs only that one import. An app that defines a class with one of these names (for example its own `Treatment`) and imports `absmartly_sdk.dart` without a prefix gets an ambiguous-import error; hide the name or import with a prefix. `Response` stays out of it, as in 2.1, because `package:http` has a class of the same name; import it from `package:absmartly_sdk/http_client.dart`.
- **Flutter widgets**: `ABSmartlyProvider`, `Treatment`, `TreatmentBuilder`, `TreatmentSwitch`, `VariableValue` and `InheritedABSmartly`.
- **Assignment rules.** An experiment's `assignmentRules` are evaluated in order; the first rule whose environments and conditions match decides the variant. An `assign` rule gives a fixed variant and a `split` rule (`"20/30/50"`) distributes units across the variants, hashing the unit with the experiment's seed. A matching rule wins over audiences, `audienceStrict`, traffic eligibility, full-on and custom assignments; only `setOverride` beats it. Its exposures carry `ruleOverride: true` and `assigned: false`. Malformed rules are skipped; a split whose value count differs from the variant count, or an out-of-range assign variant, falls back to normal assignment.
- `semver_eq`, `semver_gt`, `semver_gte`, `semver_lt` and `semver_lte` JSON expression operators, and `contains` as another name for `in`. A number operand is compared in the JavaScript SDK's string form, independent of the locale.
- `ClientConfig.setApplicationVersion`/`getApplicationVersion` and the `applicationVersion` key of `createFromProperties`. `X-Application-Version` carries it, trimmed, only when it is a whole number of at most 18 digits, otherwise `0`, since the collector reads the header as a 64-bit integer.
- `Client.getApplication()`, `getEnvironment()`, `getApplicationVersion()`, `getAgent()`, `getAgentName()` and `getAgentVersion()`; `SdkVersion`. For a custom class that implements `Client`, `getApplication()`/`getEnvironment()` return null, so audiences see no system `application`/`environment` for its contexts.
- Numeric unit UIDs: `setUnit`/`setUnits` on `Context` and `ContextConfig` also accept a number, hashed after rounding to a whole number like JavaScript's `toFixed(0)` (so `125.75` assigns like `"126"`). `getUnit`/`getUnits` keep returning strings (`String?`, `Map<String, String>`), a number in its `toString()` form; the new `getUnitValue`/`getUnitValues` return the UIDs as set.
- `ContextPublisher`, `DefaultContextPublisher` and `ABSmartlyConfig.setContextPublisher`: the JavaScript SDK's names for `ContextEventHandler`, `DefaultContextEventHandler` and `setContextEventHandler`, which keep working unchanged.
- `EventType.finalize` (the same value as `EventType.close`), and `Context.finalize()`, `isFinalized()`, `isFinalizing()`.
- `Context.readyError()`, custom field values (`getCustomFieldKeys`, `getCustomFieldValue`, `getCustomFieldValueType` and the `customField…` aliases), and `Experiment.customFieldValues`.
- `Experiment.assignmentRules` and `Exposure.ruleOverride`, as optional constructor parameters.
- Named-parameter factories on `ClientConfig.create`, `ContextConfig.create`, `ABSmartlyConfig.create` and `DefaultHTTPClientConfig.create`; `DefaultHTTPClient(config, httpClient:)`.

The members added to `Context`, `ContextConfig`, `Client`, `ClientConfig`, `ABSmartlyConfig`, `AudienceMatcher`, `Experiment` and `Exposure` are extension members, so classes that `implements` those types keep compiling.

### Changed
These follow the cross-SDK contract all ABsmartly SDKs implement in this release.
- **`X-Agent` is now `absmartly-dart-sdk/<version>`** (was `absmartly-dart-sdk`). The collector stores it as the exposure's `agent`, so exports or dashboards that filter on `agent = 'absmartly-dart-sdk'` must match the new value.
- **Every published exposure now carries `ruleOverride`**: `true` when an assignment rule chose the variant, otherwise `false`, as the JavaScript SDK sends it. Code that compares the publish payload byte for byte (for example a custom `ContextEventSerializer` test) sees the extra key.
- **Audiences always see `application` and `environment`.** The application and environment names from the client config are put in the attributes audience filters and rule conditions read. Attributes you set with the same name still win. They are not added to the publish payload, and no `app_version` attribute is injected. This affects experiments with an `application` or `environment` audience condition: with Audience enforced (`audienceStrict`) such a unit got control on every evaluation before and is now randomised normally; without it, only the `audienceMismatch` flag of its exposures changes.
- **The context fetch (`GET /context`) sends the SDK headers** (`X-API-Key`, `X-Application`, `X-Environment`, `X-Application-Version`, `X-Agent`), as the publish request always did. It affects proxies or mocks that matched the old header-less request.
- **Audiences are re-evaluated after `setAttribute`.** If a new attribute flips an experiment's audience match, the next read re-assigns and exposes the unit again: with `audienceStrict` it moves between control and its randomised variant; without it, it keeps its variant and only the `audienceMismatch` flag of the new exposure changes.
- **`refresh()` on a context whose data failed to load does nothing** (it fetched again before). Events of a failed context were already never published, so only code that relied on a refresh to start serving variants is affected; create a new context instead.
- **Unit UIDs with emoji or other characters outside the Basic Multilingual Plane** are hashed from their correct UTF-8 bytes, as in every other ABsmartly SDK and the collector (2.1 hashed the UTF-16 surrogates). Units whose UID contains such a character move once to the variant the other SDKs already gave them, and are exposed again.
- **A failed final publish leaves the context open.** `close()` completes with the error and keeps the events queued, so it can be retried (2.1 marked the context closed and lost them). Code that treated a failed `close()` as closed should retry or discard the context.
- **`setOverride`/`setOverrides` work after `close()`** (they threw), as in the other SDKs.
- **Variables shared by several experiments** resolve from the experiment with the lowest id in which the unit is assigned, as in the other SDKs, instead of the first one in the payload.

### Fixed
- JSON expression `eq`/`in` compare nested lists and maps by value, as the other SDKs do.
- Integer split weights (`1` instead of `1.0`) are accepted when deserializing context data, and a response that cannot be deserialized fails the context instead of completing with null.
- `getUnits()` returns the units; it returned an empty map.
- Publishing no longer sends each unit twice.
- A failed publish keeps its events queued for the next publish instead of dropping them; one publish runs at a time, and `close()` waits for an in-flight publish.
- A throwing `ContextEventLogger` no longer breaks the context.
- `track(name, properties)` copies `properties`, so later changes to the map are not published.
- `DefaultVariableParser` rejects variant configs that are not JSON objects instead of throwing a `TypeError` later.
- A negative publish delay disables the automatic publish instead of publishing immediately.
- The Flutter dependency is gone from the core models, so `absmartly_dart` runs on the Dart VM.

`absmartly_dart` caps `intl` at `<1.0.0` (2.1 left it open-ended), because pub.dev requires an upper bound; every released `intl` (latest 0.20.3) still resolves.

## 1.0.0

First Flutter SDK Version
