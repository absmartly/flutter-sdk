# ABsmartly Dart SDK

Pure Dart SDK for [ABsmartly](https://www.absmartly.com/) A/B testing platform. This package has no Flutter dependencies and can be used in any Dart environment (CLI, server-side, Flutter).

## Compatibility

The ABsmartly Dart SDK is compatible with Dart versions 2.18.6 and later.

## Getting Started

### Install the SDK

Add to your `pubspec.yaml`:

```yaml
dependencies:
  absmartly_dart: ^2.1.2
```

### Import and Initialize the SDK

#### Recommended: Simple API

```dart
import 'package:absmartly_dart/absmartly_dart.dart';

void main() async {
  // Simple, clean initialization - just provide your credentials
  final sdk = ABsmartly.create(
    endpoint: 'https://your-company.absmartly.io/v1',
    apiKey: 'YOUR-API-KEY',
    application: 'website',
    environment: 'development',
  );
}
```

#### Advanced: Manual Client Configuration

For advanced use cases where you need custom HTTP clients or configurations:

```dart
import 'package:absmartly_dart/absmartly_dart.dart';

void main() async {
  final clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR-API-KEY")
    ..setApplication("website")
    ..setEnvironment("development");

  final httpClientConfig = DefaultHTTPClientConfig()
    ..setMaxRetries(3)
    ..setConnectTimeout(5000);

  final client = Client.create(
    clientConfig,
    httpClient: DefaultHTTPClient.create(httpClientConfig),
  );

  final sdkConfig = ABsmartlyConfig.create()
    ..setClient(client);

  final sdk = ABsmartly(sdkConfig);
}
```

**SDK Options**

| Config                  | Type                              | Required? |   Default   | Description                                                                                                                                                                   |
| :---------------------- | :-------------------------------- | :-------: | :---------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| endpoint                | `String`                          |  &#9989;  | `null`      | The URL to your API endpoint. Most commonly `"your-company.absmartly.io"`                                                                                                     |
| apiKey                  | `String`                          |  &#9989;  | `null`      | Your API key which can be found on the Web Console.                                                                                                                           |
| environment             | `String`                          |  &#9989;  | `null`      | The environment of the platform where the SDK is installed. Environments are created on the Web Console and should match the available environments in your infrastructure.   |
| application             | `String`                          |  &#9989;  | `null`      | The name of the application where the SDK is installed. Applications are created on the Web Console and should match the applications where your experiments will be running. |
| retries                 | `int`                             |  &#10060; | `5`         | Number of retry attempts for failed HTTP requests                                                                                                                             |
| timeout                 | `int`                             |  &#10060; | `3000`      | Connection timeout in milliseconds                                                                                                                                            |
| contextEventLogger      | `ContextEventLogger`              |  &#10060; | `null`      | Callback to handle SDK events (ready, exposure, goal, etc.)                                                                                                                   |
| contextDataProvider     | `ContextDataProvider`             |  &#10060; | auto        | Custom provider for context data (advanced usage)                                                                                                                             |
| contextEventHandler     | `ContextEventHandler`             |  &#10060; | auto        | Custom handler for publishing events (advanced usage)                                                                                                                         |

**Note:** All parameters are optional when providing custom `contextDataProvider` or `contextEventHandler` implementations.

## Create a New Context Request

### Synchronously

```dart
final ContextConfig contextConfig = ContextConfig.create()
    .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8");

final Context? context = sdk.createContext(contextConfig).waitUntilReady();

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

final Context context = sdk.createContext(contextConfig).waitUntilReady();

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

## Platform Support

| Platform    | Support |
|-------------|---------|
| Dart VM     | Yes |
| Flutter     | Yes (use `absmartly_sdk` for Flutter-specific features) |
| Web         | Yes |
| Server-side | Yes |

## Flutter Users

For Flutter applications, use the [`absmartly_sdk`](https://pub.dev/packages/absmartly_sdk) package which wraps this SDK and may include Flutter-specific features in the future.

## About A/B Smartly

**A/B Smartly** is the leading provider of state-of-the-art, on-premises, full-stack experimentation platforms for engineering and product teams that want to confidently deploy features as fast as they can develop them.
A/B Smartly's real-time analytics helps engineering and product teams ensure that new features will improve the customer experience without breaking or degrading performance and/or business metrics.

### Have a look at our growing list of clients and SDKs:
- [JavaScript SDK](https://www.github.com/absmartly/javascript-sdk)
- [Java SDK](https://www.github.com/absmartly/java-sdk)
- [PHP SDK](https://www.github.com/absmartly/php-sdk)
- [Swift SDK](https://www.github.com/absmartly/swift-sdk)
- [Vue2 SDK](https://www.github.com/absmartly/vue2-sdk)
- [Vue3 SDK](https://www.github.com/absmartly/vue3-sdk)
- [React SDK](https://www.github.com/absmartly/react-sdk)
- [Python3 SDK](https://www.github.com/absmartly/python3-sdk)
- [Go SDK](https://www.github.com/absmartly/go-sdk)
- [Ruby SDK](https://www.github.com/absmartly/ruby-sdk)
- [.NET SDK](https://www.github.com/absmartly/dotnet-sdk)
- [Dart SDK](https://www.github.com/absmartly/dart-sdk) (this package)
- [Flutter SDK](https://www.github.com/absmartly/flutter-sdk)

## Documentation

- [Full Documentation](https://docs.absmartly.com/)
- [API Reference](https://pub.dev/documentation/absmartly_dart/latest/)

## License

MIT License - see [LICENSE](../../LICENSE) for details.
