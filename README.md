# ABsmartly Flutter SDK

A/B Smartly SDK for Flutter and Dart. This repository contains two packages: a pure Dart SDK (`absmartly_dart`) for any Dart environment, and a Flutter SDK (`absmartly_sdk`) that wraps the Dart SDK with Flutter-specific widgets and providers.

## Packages

| Package | Description | Pub |
|---------|-------------|-----|
| [dart_sdk](packages/dart_sdk/) | Pure Dart SDK - works in any Dart environment | [![pub](https://img.shields.io/pub/v/absmartly_dart.svg)](https://pub.dev/packages/absmartly_dart) |
| [flutter_sdk](packages/flutter_sdk/) | Flutter SDK - includes Flutter-specific widgets and providers | [![pub](https://img.shields.io/pub/v/absmartly_sdk.svg)](https://pub.dev/packages/absmartly_sdk) |

### Which Package Should I Use?

- **Flutter apps**: Use `absmartly_sdk` (the Flutter package) for widgets and provider support
- **Dart CLI/Server**: Use `absmartly_dart` (the pure Dart package)
- **Package authors**: Depend on `absmartly_dart` for maximum compatibility

## Compatibility

The A/B Smartly Flutter SDK is compatible with:

- **Dart**: Version 2.18.6 and later (up to Dart 3.x)
- **Flutter**: Version 1.17.0 and later

## Installation

### Flutter SDK

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  absmartly_sdk: ^2.1.2
```

### Dart SDK (pure Dart, no Flutter dependency)

```yaml
dependencies:
  absmartly_dart: ^2.1.2
```

Then run:

```bash
flutter pub get
# or for pure Dart:
dart pub get
```

## Getting Started

### Initialization (Dart SDK)

This example assumes an API Key, an Application, and an Environment have been created in the A/B Smartly web console.

```dart
import 'package:absmartly_dart/absmartly_dart.dart';

void main() async {
  final clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR_API_KEY")
    ..setApplication("website")
    ..setEnvironment("development");

  final sdkConfig = ABSmartlyConfig.create()
    ..setClient(Client.create(clientConfig));

  final sdk = ABSmartly(sdkConfig);
}
```

### Initialization (Flutter SDK with ABSmartlyProvider)

The recommended approach for Flutter apps is to wrap your application with `ABSmartlyProvider`, which manages the SDK lifecycle and makes the context available throughout the widget tree.

#### Simple Setup with ABSmartlyProvider.create

```dart
import 'package:flutter/material.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';

void main() {
  runApp(
    ABSmartlyProvider.create(
      endpoint: "https://your-company.absmartly.io/v1",
      apiKey: "YOUR_API_KEY",
      environment: "production",
      application: "my_flutter_app",
      units: {"user_id": "12345"},
      child: const MyApp(),
    ),
  );
}
```

#### Alternative: Setup with Pre-created SDK and Context

```dart
import 'package:flutter/material.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';

void main() async {
  final clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR_API_KEY")
    ..setApplication("my_flutter_app")
    ..setEnvironment("production");

  final sdkConfig = ABSmartlyConfig.create()
    ..setClient(Client.create(clientConfig));

  final sdk = ABSmartly(sdkConfig);

  final contextConfig = ContextConfig.create()
    ..setUnit("user_id", "12345");

  final context = sdk.createContext(contextConfig);

  runApp(
    ABSmartlyProvider(
      sdk: sdk,
      context: context,
      child: const MyApp(),
    ),
  );
}
```

**SDK Options**

| Config      | Type     | Required? |   Default   | Description                                                                                                                                                                 |
| :---------- | :------- | :-------: | :---------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| endpoint    | `String` |  &#9989;  | `undefined` | The URL to your API endpoint. Most commonly `"your-company.absmartly.io"`                                                                                                   |
| apiKey      | `String` |  &#9989;  | `undefined` | Your API key which can be found on the Web Console.                                                                                                                         |
| environment | `String` |  &#9989;  | `undefined` | The environment of the platform where the SDK is installed. Environments are created on the Web Console and should match the available environments in your infrastructure. |
| application | `String` |  &#9989;  | `undefined` | The name of the application where the SDK is installed. Applications are created on the Web Console and should match the applications where your experiments will be running.|

**ABSmartlyProvider Options**

| Config                 | Type               | Required? | Default                        | Description                                                     |
| :--------------------- | :----------------- | :-------: | :----------------------------- | :-------------------------------------------------------------- |
| defaultLoadingBehavior | `LoadingBehavior`  | &#10060;  | `LoadingBehavior.placeholder`  | How Treatment widgets behave while the context is loading.      |
| readyTimeout           | `Duration`         | &#10060;  | `Duration(seconds: 3)`         | Timeout before falling back to control variant.                 |

**LoadingBehavior Values**

| Value         | Description                                                                                   |
| :------------ | :-------------------------------------------------------------------------------------------- |
| `placeholder` | Show empty SizedBox while loading, fall back to control variant after the readyTimeout elapses. |
| `control`     | Show the control variant (0) immediately while loading.                                        |

## Creating a New Context

### Synchronously

```dart
final contextConfig = ContextConfig.create()
  ..setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final context = sdk.createContext(contextConfig);
context.waitUntilReady();
```

### Asynchronously

```dart
final contextConfig = ContextConfig.create()
  ..setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final context = await sdk.createContext(contextConfig).waitUntilReady();
```

### With Pre-fetched Data

When doing full-stack experimentation with A/B Smartly, we recommend creating a context only once on the server-side. Creating a context involves a round-trip to the A/B Smartly event collector. You can avoid repeating the round-trip on the client-side by passing the pre-fetched data directly.

```dart
final contextConfig = ContextConfig.create()
  ..setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final context = await sdk.createContext(contextConfig).waitUntilReady();

final anotherContextConfig = ContextConfig.create()
  ..setUnit("session_id", "another_user_session_id");

final anotherContext = sdk.createContextWith(anotherContextConfig, context.getData());
assert(anotherContext.isReady()); // no need to wait
```

### Refreshing the Context with Fresh Experiment Data

For long-running contexts, the context is usually created once when the application is first started. However, any experiments being tracked in your production code, but started after the context was created, will not be triggered. To mitigate this, use the `setRefreshInterval()` method on the context config.

```dart
final contextConfig = ContextConfig.create()
  ..setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8")
  ..setRefreshInterval(4 * 60 * 60 * 1000); // every 4 hours
```

Alternatively, the `refresh()` method can be called manually. The `refresh()` method pulls updated experiment data from the A/B Smartly collector and will trigger recently started experiments when `getTreatment()` is called again.

```dart
await context.refresh();
```

### Setting Extra Units

You can add additional units to a context by calling the `setUnit()` or `setUnits()` methods. These methods may be used, for example, when a user logs in to your application and you want to use the new unit type in the context.

Please note, you cannot override an already set unit type as that would be a change of identity and would throw an exception. In this case, you must create a new context instead. The `setUnit()` and `setUnits()` methods can be called before the context is ready.

```dart
context.setUnit("db_user_id", "1000013");

context.setUnits({
  "db_user_id": "1000013",
});
```

## Basic Usage

### Selecting a Treatment

```dart
final treatment = context.getTreatment("exp_test_experiment");
if (treatment == 0) {
  // user is in control group (variant 0)
} else {
  // user is in treatment group
}
```

### Treatment Variables

```dart
final buttonColor = context.getVariableValue("button_color", "red");
```

### Peek at Treatment Variants

Although generally not recommended, it is sometimes necessary to peek at a treatment or variable without triggering an exposure. The A/B Smartly SDK provides `peekTreatment()` and `peekVariableValue()` methods for that.

```dart
final variant = context.peekTreatment("exp_test_experiment");
```

#### Peeking at Variables

```dart
final value = context.peekVariableValue("button_color", "red");
```

### Overriding Treatment Variants

During development, for example, it is useful to force a treatment for an experiment. This can be achieved with the `setOverride()` and/or `setOverrides()` methods. These methods can be called before the context is ready.

```dart
context.setOverride("exp_test_experiment", 1);

context.setOverrides({
  "exp_test_experiment": 1,
  "exp_another_experiment": 0,
});
```

## Advanced

### Context Attributes

Attributes are used to pass meta-data about the user and/or the request. They can be used later in the Web Console to create segments or audiences. They can be set using the `setAttribute()` or `setAttributes()` methods, before or after the context is ready.

```dart
context.setAttribute("user_agent", "flutter");

context.setAttributes({
  "customer_age": "new_customer",
  "app_version": "2.1.0",
});
```

### Custom Assignments

Sometimes it may be necessary to override the automatic selection of a variant. For example, if you wish to have your variant chosen based on data from an API call. This can be accomplished using the `setCustomAssignment()` method.

```dart
context.setCustomAssignment("exp_test_experiment", 1);

context.setCustomAssignments({
  "exp_test_experiment": 1,
});
```

### Tracking Goals

Goals are created in the A/B Smartly web console.

```dart
context.track("payment", {
  "item_count": 1,
  "total_amount": 1999.99,
});
```

### Publishing Pending Data

Sometimes it is necessary to ensure all events have been published to the A/B Smartly collector, before proceeding. You can explicitly call the `publish()` method.

```dart
await context.publish();
```

### Finalizing

The `close()` method will ensure all events have been published to the A/B Smartly collector, like `publish()`, and will also "seal" the context, throwing an error if any method that could generate an event is called.

```dart
await context.close();
```

### Using a Custom Event Logger

The A/B Smartly SDK can be instantiated with an event logger used for all contexts. In addition, an event logger can be specified when creating a particular context, in the `ContextConfig`.

```dart
class CustomEventLogger implements ContextEventLogger {
  @override
  void handleEvent(Context context, EventType event, dynamic data) {
    switch (event) {
      case EventType.exposure:
        final Exposure exposure = data;
        print("exposed to experiment ${exposure.name}");
        break;
      case EventType.goal:
        final GoalAchievement goal = data;
        print("goal tracked: ${goal.name}");
        break;
      case EventType.error:
        print("error: $data");
        break;
      case EventType.publish:
      case EventType.ready:
      case EventType.refresh:
      case EventType.close:
        break;
    }
  }
}
```

```dart
final contextConfig = ContextConfig.create()
  ..setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8")
  ..setContextEventLogger(CustomEventLogger());
```

**Event Types**

| Event      | When                                                     | Data                                          |
| ---------- | -------------------------------------------------------- | --------------------------------------------- |
| `error`    | `Context` receives an error                              | Error object thrown                           |
| `ready`    | `Context` turns ready                                    | Data used to initialize the context           |
| `refresh`  | `Context.refresh()` method succeeds                      | Data used to refresh the context              |
| `publish`  | `Context.publish()` method succeeds                      | Data sent to the A/B Smartly event collector  |
| `exposure` | `Context.getTreatment()` method succeeds on first exposure | Exposure data enqueued for publishing       |
| `goal`     | `Context.track()` method succeeds                        | Goal data enqueued for publishing             |
| `close`    | `Context.close()` method succeeds the first time         | undefined                                     |

## Flutter Widgets

The Flutter SDK provides declarative widgets for working with experiments in your widget tree.

### Treatment Widget

The `Treatment` widget renders different widgets based on the assigned variant. Pass a map of variant indices to widgets.

```dart
Treatment(
  name: "exp_checkout_button",
  variants: {
    0: const OldCheckoutButton(),
    1: const NewCheckoutButton(),
  },
)
```

You can provide an optional loading widget to show while the context is being fetched:

```dart
Treatment(
  name: "exp_checkout_button",
  loading: const CircularProgressIndicator(),
  variants: {
    0: const OldCheckoutButton(),
    1: const NewCheckoutButton(),
  },
)
```

### TreatmentBuilder Widget

The `TreatmentBuilder` widget provides the variant number and all experiment variables to a builder callback, giving you more flexibility than `Treatment`.

```dart
TreatmentBuilder(
  name: "exp_price_experiment",
  builder: (context, variant, variables) {
    final price = variables["price"] ?? 9.99;
    return PriceTag(
      price: price,
      highlighted: variant == 1,
    );
  },
)
```

### TreatmentSwitch Widget

The `TreatmentSwitch` widget works with `TreatmentVariant` children, similar to a switch statement. Variants can be specified as integers or letters (`'A'`, `'B'`, `'C'`).

```dart
TreatmentSwitch(
  name: "exp_hero_experiment",
  children: [
    TreatmentVariant(variant: 0, child: const ClassicHero()),
    TreatmentVariant(variant: 1, child: const ModernHero()),
    TreatmentVariant(variant: "C", child: const MinimalHero()),
  ],
)
```

### VariableValue Widget

The `VariableValue` widget provides a type-safe way to access experiment variable values and build UI from them.

```dart
VariableValue<String>(
  name: "button_text",
  defaultValue: "Click me",
  builder: (value) => ElevatedButton(
    onPressed: () {},
    child: Text(value),
  ),
)
```

### Accessing the Context from Widgets

Use `ABSmartlyProvider.of(context)` to access the SDK and context from anywhere in the widget tree.

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final absmartly = ABSmartlyProvider.of(context);
    final ctx = absmartly.context;

    return ElevatedButton(
      onPressed: () {
        ctx.track("button_clicked", {"page": "home"});
      },
      child: const Text("Track Event"),
    );
  }
}
```

### Resetting the Context

When a user's identity changes (for example, after login), reset the context with new units:

```dart
final absmartly = ABSmartlyProvider.of(context, listen: false);

await absmartly.resetContext(units: {"user_id": "new_user_id"});
```

## About A/B Smartly

**A/B Smartly** is the leading provider of state-of-the-art, on-premises, full-stack experimentation platforms for engineering and product teams that want to confidently deploy features as fast as they can develop them. A/B Smartly's real-time analytics helps engineering and product teams ensure that new features will improve the customer experience without breaking or degrading performance and/or business metrics.

### Have a look at our growing list of clients and SDKs:
- [JavaScript SDK](https://www.github.com/absmartly/javascript-sdk)
- [React SDK](https://www.github.com/absmartly/react-sdk)
- [Vue2 SDK](https://www.github.com/absmartly/vue2-sdk)
- [Vue3 SDK](https://www.github.com/absmartly/vue3-sdk)
- [Java SDK](https://www.github.com/absmartly/java-sdk)
- [Android SDK](https://www.github.com/absmartly/android-sdk)
- [Swift SDK](https://www.github.com/absmartly/swift-sdk)
- [Dart SDK](https://www.github.com/absmartly/dart-sdk)
- [Flutter SDK](https://www.github.com/absmartly/flutter-sdk) (this package)
- [PHP SDK](https://www.github.com/absmartly/php-sdk)
- [Python3 SDK](https://www.github.com/absmartly/python3-sdk)
- [Go SDK](https://www.github.com/absmartly/go-sdk)
- [Ruby SDK](https://www.github.com/absmartly/ruby-sdk)
- [.NET SDK](https://www.github.com/absmartly/dotnet-sdk)
- [Rust SDK](https://www.github.com/absmartly/rust-sdk)
