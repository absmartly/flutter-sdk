## 2.2.0 (unreleased)

Applies to `absmartly_dart` and `absmartly_sdk`.

### BREAKING
- `ContextEventHandler` renamed to `ContextPublisher` (`setContextPublisher` added).
- JSON expr `in` operator is haystack-first (CONTAINS alias added); `eq(null, null)` returns null.
- **BREAKING:** read methods (treatment, peek, variable value, variable keys, experiments, custom fields) now throw "ABsmartly Context is not yet ready." before the context is ready, and a finalized error after finalize, instead of returning defaults. A context whose load failed is ready and returns control/default values.

### Added
- `finalize`/`isFinalized`/`isFinalizing` aliases, custom field support (`customFieldKeys`/`Value`/`ValueType`), `readyError`.
- Named-parameter factory constructors for config classes.

### Fixed
- Assignment cache preserved on refresh; publish error handling; UTF-8 encoding of astral characters in unit hashing.
- Integer split weights accepted when deserializing context data; stale async guards and provider `didUpdateWidget`.

## 1.0.0

First Flutter SDK Version
