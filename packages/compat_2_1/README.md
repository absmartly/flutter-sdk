Code written against the published `absmartly_sdk` 2.1.2 API (its README,
deep imports, and `implements`/`extends` of its public classes). CI compiles
and runs it against this repository so 2.x stays source compatible. Do not
update it for new APIs; it must keep compiling against 2.1.2 itself.

The explicit context, ABSmartly config, model, client, client-config,
context-config and audience-matcher implementations mirror the published 2.1.2
instance interfaces (git `fe9d73b`) without `noSuchMethod`, so adding an
instance member to any of them breaks the compile gate.
The runtime test omits the result of `Context.getUnits()`: 2.1.2 returned an
empty map there, while the current SDK fixes it. The fix is tested separately in
`packages/dart_sdk/test/context_test.dart`.
