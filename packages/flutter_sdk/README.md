# ABsmartly Flutter SDK

Flutter SDK for [ABsmartly](https://www.absmartly.com/) A/B testing platform. This package wraps the pure Dart SDK and provides seamless Flutter integration.

## Compatibility

The ABsmartly Flutter SDK is compatible with:
- Dart versions 2.18.6 and later
- Flutter 1.17.0 and later

## Getting Started

### Install the SDK

Add to your `pubspec.yaml`:

```yaml
dependencies:
  absmartly_sdk: ^2.1.2
```

### Import and Initialize the SDK

```dart
import 'package:absmartly_sdk/absmartly_sdk.dart';

void main() async {
  final ClientConfig clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR-API-KEY")
    ..setApplication("website")
    ..setEnvironment("development");

  final ABSmartlyConfig sdkConfig = ABSmartlyConfig.create()
      .setClient(Client.create(clientConfig));
  final ABSmartly sdk = ABSmartly(sdkConfig);

  runApp(MyApp(sdk: sdk));
}
```

**SDK Options**

| Config      | Type                              | Required? |   Default   | Description                                                                                                                                                                   |
| :---------- | :-------------------------------- | :-------: | :---------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| endpoint    | `String`                          |  &#9989;  | `undefined` | The URL to your API endpoint. Most commonly `"your-company.absmartly.io"`                                                                                                     |
| apiKey      | `String`                          |  &#9989;  | `undefined` | Your API key which can be found on the Web Console.                                                                                                                           |
| environment | `"production"` or `"development"` |  &#9989;  | `undefined` | The environment of the platform where the SDK is installed. Environments are created on the Web Console and should match the available environments in your infrastructure.   |
| application | `String`                          |  &#9989;  | `undefined` | The name of the application where the SDK is installed. Applications are created on the Web Console and should match the applications where your experiments will be running. |

## Create a New Context Request

### Synchronously

```dart
final ContextConfig contextConfig = ContextConfig.create()
    .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final Context? context = await sdk.createContext(contextConfig).waitUntilReady();

if (context != null) {
  print("context ready");
}
```

### Asynchronously

```dart
final ContextConfig contextConfig = ContextConfig.create()
    .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final Context? context = await sdk.createContext(contextConfig).waitUntilReady();

if (context != null) {
  print("context ready");
}
```

### With Prefetched Data

```dart
final ContextConfig contextConfig = ContextConfig.create()
    .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final Context context = await sdk.createContext(contextConfig).waitUntilReady();

final ContextConfig anotherContextConfig = ContextConfig.create()
    .setUnit("session_id", "another-user-id");

final Context anotherContext = sdk.createContextWith(anotherContextConfig, context.getData());
assert(anotherContext.isReady()); // no need to wait
```

### Refreshing the Context with Fresh Experiment Data

For long-running contexts, use `setRefreshInterval()` to automatically refresh experiment data:

```dart
final ContextConfig contextConfig = ContextConfig.create()
    .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8")
    .setRefreshInterval(TimeUnit.HOURS.toMillis(4)); // every 4 hours
```

Or call `refresh()` manually:

```dart
context.refresh();
```

### Setting Extra Units

```dart
context.setUnit("db_user_id", "1000013");
context.setUnits({
  "db_user_id": "1000013"
});
```

> **Note:** You cannot override an already set unit type. Create a new context instead.

## Basic Usage

### Selecting a Treatment

```dart
if (await context.getTreatment("exp_test_experiment") == 0) {
  // user is in control group (variant 0)
} else {
  // user is in treatment group
}
```

### Treatment Variables

```dart
var defaultButtonColorValue = "red";
var buttonColor = context.getVariableValue("button.color", defaultButtonColorValue);
```

### Peek at Treatment Variants

Check treatment without triggering an exposure:

```dart
var value = await context.peekTreatment("experimentName");
```

### Overriding Treatment Variants

```dart
context.setOverride("exp_test_experiment", 1);
context.setOverrides({
  "exp_test_experiment": 1,
  "exp_another_experiment": 0,
});
```

## Advanced

### Context Attributes

```dart
context.setAttribute("user_agent", "Mozilla/5.0...");
context.setAttributes({
  "customer_age": "new_customer",
});
```

### Custom Assignments

```dart
context.setCustomAssignment("experimentName", 1);
context.setCustomAssignments({"experimentName": 1});
```

### Tracking Goals

```dart
context.track("payment", {
  "item_count": 1,
  "total_amount": 1999.99
});
```

### Publish

Ensure all events are published:

```dart
await context.publish();
```

### Finalize

Close the context and publish pending events:

```dart
await context.close();
```

### Custom Event Logger

```dart
class CustomEventLogger implements ContextEventLogger {
  @override
  void handleEvent(Context context, EventType event, dynamic data) {
    switch (event) {
      case EventType.Exposure:
        final Exposure exposure = data;
        print("exposed to experiment ${exposure.name}");
        break;
      case EventType.Goal:
        final GoalAchievement goal = data;
        print("goal tracked: ${goal.name}");
        break;
      case EventType.Error:
        print("error: $data");
        break;
      case EventType.Publish:
      case EventType.Ready:
      case EventType.Refresh:
      case EventType.Close:
        break;
    }
  }
}

// Usage
contextConfig.setContextEventLogger(CustomEventLogger());
```

**Event Types**

| Event      | When                                               | Data                                   |
| ---------- | -------------------------------------------------- | -------------------------------------- |
| `Error`    | Context receives an error                          | Error object                           |
| `Ready`    | Context turns ready                                | ContextData used to initialize         |
| `Refresh`  | `refresh()` method succeeds                        | ContextData used to refresh            |
| `Publish`  | `publish()` method succeeds                        | PublishEvent sent to collector         |
| `Exposure` | `getTreatment()` succeeds on first exposure        | Exposure enqueued for publishing       |
| `Goal`     | `track()` method succeeds                          | GoalAchievement enqueued for publishing|
| `Close`    | `close()` method succeeds the first time           | null                                   |

## Flutter Integration

This package is designed for Flutter applications and includes all functionality from the [Dart SDK](../dart_sdk/) plus Flutter-specific widgets for declarative A/B testing in your widget tree.

### ABSmartlyProvider

Wrap your app with `ABSmartlyProvider` to make the SDK and context available throughout your widget tree:

```dart
import 'package:absmartly_sdk/absmartly_sdk.dart';

void main() async {
  final clientConfig = ClientConfig()
    ..setEndpoint('https://your-company.absmartly.io/v1')
    ..setAPIKey('YOUR-API-KEY')
    ..setApplication('website')
    ..setEnvironment('development');

  final client = Client.create(clientConfig);
  final sdkConfig = ABSmartlyConfig.create()..setClient(client);
  final sdk = ABSmartly(sdkConfig);

  final contextConfig = ContextConfig.create()
    ..setUnit('user_id', 'user-123');
  final context = sdk.createContext(contextConfig);

  runApp(
    ABSmartlyProvider(
      sdk: sdk,
      context: context,
      defaultLoadingBehavior: LoadingBehavior.control,
      child: const MyApp(),
    ),
  );
}
```

**Provider Options**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sdk` | `ABSmartly` | required | The SDK instance |
| `context` | `Context` | required | The experiment context |
| `defaultLoadingBehavior` | `LoadingBehavior` | `placeholder` | How to handle loading states |
| `readyTimeout` | `Duration` | 3 seconds | Timeout before falling back to control |

**Loading Behaviors**

- `LoadingBehavior.placeholder` - Show empty `SizedBox` while loading, fall back to control after timeout
- `LoadingBehavior.control` - Immediately show control variant (may cause flickering if context loads quickly)

### Treatment Widget

Use the `Treatment` widget to render different UI based on experiment variants:

```dart
Treatment(
  name: 'checkout_experiment',
  variants: {
    0: OldCheckoutButton(),  // Control
    1: NewCheckoutButton(),  // Variant B
    2: MinimalCheckoutButton(),  // Variant C
  },
)
```

With custom loading widget:

```dart
Treatment(
  name: 'checkout_experiment',
  loading: CircularProgressIndicator(),
  variants: {
    0: OldCheckoutButton(),
    1: NewCheckoutButton(),
  },
)
```

### TreatmentBuilder Widget

Use `TreatmentBuilder` when you need access to experiment variables:

```dart
TreatmentBuilder(
  name: 'price_experiment',
  builder: (context, variant, variables) {
    final price = variables['price'] ?? 9.99;
    return PriceTag(
      price: price,
      highlighted: variant == 1,
    );
  },
)
```

### TreatmentSwitch Widget

Use `TreatmentSwitch` with `TreatmentVariant` children for a more declarative style:

```dart
TreatmentSwitch(
  name: 'hero_experiment',
  children: [
    TreatmentVariant(
      variant: 0,  // or 'A' for control
      child: ClassicHero(),
    ),
    TreatmentVariant(
      variant: 1,  // or 'B' for first variant
      child: ModernHero(),
    ),
    TreatmentVariant(
      variant: 'C',  // letter notation supported
      child: MinimalHero(),
    ),
  ],
)
```

### Accessing Provider Data

Access the SDK and context from anywhere in the widget tree:

```dart
// In a widget
final data = ABSmartlyProvider.of(context);
final sdk = data.sdk;
final abContext = data.context;
final isReady = data.isReady;

// Null-safe access
final data = ABSmartlyProvider.maybeOf(context);
if (data != null) {
  // Provider available
}
```

### Example App

See the [example](example/) directory for a complete Flutter application demonstrating the SDK:

```bash
cd example
flutter run
```

## Dart-Only Projects

For non-Flutter Dart projects (CLI tools, server-side), use the [`absmartly_dart`](https://pub.dev/packages/absmartly_dart) package directly for a smaller dependency footprint.

## Documentation

- [Full Documentation](https://docs.absmartly.com/)
- [API Reference](https://pub.dev/documentation/absmartly_sdk/latest/)

## License

MIT License - see [LICENSE](../../LICENSE) for details.
