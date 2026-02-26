# ABsmartly Dart SDK

Pure Dart SDK for [ABsmartly](https://www.absmartly.com/) A/B testing platform. This package has no Flutter dependencies and can be used in any Dart environment (CLI, server-side, Flutter).

## Compatibility

The ABsmartly Dart SDK is compatible with Dart versions 2.18.6 and later (including Dart 3.x).

| Platform    | Support |
|-------------|---------|
| Dart VM     | Yes     |
| Flutter     | Yes (use [`absmartly_sdk`](https://pub.dev/packages/absmartly_sdk) for Flutter-specific features) |
| Web         | Yes     |
| Server-side | Yes     |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  absmartly_dart: ^2.1.2
```

Then run:

```shell
dart pub get
```

## Getting Started

Please follow the [installation](#installation) instructions before trying the following code.

### Import the SDK

```dart
import 'package:absmartly_dart/absmartly_dart.dart';
```

### Initialization

This example assumes an API Key, an Application, and an Environment have been created in the A/B Smartly web console.

```dart
final clientConfig = ClientConfig.create(
    endpoint: "https://your-company.absmartly.io/v1",
    apiKey: "YOUR-API-KEY",
    application: "website",
    environment: "development",
);

final sdkConfig = ABSmartlyConfig.create(
    client: Client.create(clientConfig),
);

final ABSmartly sdk = ABSmartly(sdkConfig);
```

<details>
<summary>Alternative: cascade setter pattern</summary>

```dart
final ClientConfig clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR-API-KEY")
    ..setApplication("website")
    ..setEnvironment("development");

final ABSmartlyConfig sdkConfig = ABSmartlyConfig.create()
    .setClient(Client.create(clientConfig));

final ABSmartly sdk = ABSmartly(sdkConfig);
```
</details>

#### Advanced Configuration

For advanced use cases where you need full control over the HTTP client and configuration:

```dart
final clientConfig = ClientConfig.create(
    endpoint: "https://your-company.absmartly.io/v1",
    apiKey: "YOUR-API-KEY",
    application: "website",
    environment: "development",
);

final httpClientConfig = DefaultHTTPClientConfig.create(
    connectTimeout: 5000,
    maxRetries: 3,
    retryInterval: 500,
);

final httpClient = DefaultHTTPClient.create(httpClientConfig);

final client = Client.create(clientConfig, httpClient: httpClient);

final sdkConfig = ABSmartlyConfig.create(client: client);

final ABSmartly sdk = ABSmartly(sdkConfig);
```

**SDK Options**

| Config      | Type                              | Required? |   Default   | Description                                                                                                                                                                   |
| :---------- | :-------------------------------- | :-------: | :---------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| endpoint    | `String`                          |  &#9989;  | `null`      | The URL to your API endpoint. Most commonly `"https://your-company.absmartly.io/v1"`                                                                                          |
| apiKey      | `String`                          |  &#9989;  | `null`      | Your API key which can be found on the Web Console.                                                                                                                           |
| environment | `String`                          |  &#9989;  | `null`      | The environment of the platform where the SDK is installed. Environments are created on the Web Console and should match the available environments in your infrastructure.   |
| application | `String`                          |  &#9989;  | `null`      | The name of the application where the SDK is installed. Applications are created on the Web Console and should match the applications where your experiments will be running. |

**HTTP Client Options**

| Config                   | Type   | Required? | Default  | Description                                          |
| :----------------------- | :----- | :-------: | :------: | :--------------------------------------------------- |
| connectTimeout           | `int`  |  &#10060; | `3000`   | HTTP connection timeout in milliseconds              |
| connectionKeepAlive      | `int`  |  &#10060; | `30000`  | Connection keep-alive duration in milliseconds       |
| connectionRequestTimeout | `int`  |  &#10060; | `1000`   | Timeout for acquiring a connection in milliseconds   |
| maxRetries               | `int`  |  &#10060; | `5`      | Maximum number of retry attempts for failed requests |
| retryInterval            | `int`  |  &#10060; | `333`    | Interval between retries in milliseconds             |

**ABSmartlyConfig Options**

| Config               | Type                     | Required? | Default | Description                                             |
| :------------------- | :----------------------- | :-------: | :-----: | :------------------------------------------------------ |
| client               | `Client`                 |  &#9989;  | `null`  | The Client instance (created from ClientConfig)         |
| contextDataProvider  | `ContextDataProvider`    |  &#10060; | auto    | Custom provider for context data (advanced usage)       |
| contextEventHandler  | `ContextEventHandler`    |  &#10060; | auto    | Custom handler for publishing events (advanced usage)   |
| contextEventLogger   | `ContextEventLogger`     |  &#10060; | `null`  | Callback to handle SDK events (ready, exposure, etc.)   |
| variableParser       | `VariableParser`         |  &#10060; | auto    | Custom parser for experiment variables (advanced usage)  |
| audienceDeserializer | `AudienceDeserializer`   |  &#10060; | auto    | Custom deserializer for audience data (advanced usage)  |

## Creating a New Context

### Synchronously

```dart
final contextConfig = ContextConfig.create(
    units: {"session_id": "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"},
);

final Context context = sdk.createContext(contextConfig).waitUntilReady();
```

Note: `waitUntilReady()` returns a `Future<Context>`. In a synchronous-style call (e.g., inside an `async` function), use `await`:

```dart
final Context context = await sdk.createContext(contextConfig).waitUntilReady();
```

### Asynchronously

```dart
final contextConfig = ContextConfig.create(
    units: {"session_id": "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"},
);

final Context context = await sdk.createContext(contextConfig).waitUntilReady();

if (context.isReady()) {
    print("context ready!");
}
```

### With Pre-fetched Data

Creating a context involves a round-trip to the A/B Smartly event collector. You can avoid repeating the round-trip by re-using data previously retrieved.

```dart
final contextConfig = ContextConfig.create(
    units: {"session_id": "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"},
);

final Context context = await sdk.createContext(contextConfig).waitUntilReady();

final anotherContextConfig = ContextConfig.create(
    units: {"session_id": "another-user-id"},
);

final Context anotherContext = sdk.createContextWith(anotherContextConfig, context.getData());
assert(anotherContext.isReady()); // no need to wait
```

### Refreshing the Context with Fresh Experiment Data

For long-running contexts, the context is usually created once when the application is first started. However, any experiments started after the context was created will not be triggered. To mitigate this, use `refreshInterval` on the context config.

```dart
final contextConfig = ContextConfig.create(
    units: {"session_id": "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"},
    refreshInterval: 4 * 60 * 60 * 1000, // every 4 hours
);
```

Alternatively, call `refresh()` manually:

```dart
await context.refresh();
```

### Setting Extra Units

You can add additional units to a context by calling `setUnit()` or `setUnits()`. For example, when a user logs in, you may want to add a user-level unit to the context. Note that **you cannot override an already set unit type** as that would be a change of identity, and will throw an exception. In this case, you must create a new context instead.

The `setUnit()` and `setUnits()` methods can be called before the context is ready.

```dart
context.setUnit("db_user_id", "1000013");

context.setUnits({
    "db_user_id": "1000013",
});
```

## Basic Usage

### Selecting a Treatment

```dart
int treatment = context.getTreatment("exp_test_experiment");

if (treatment == 0) {
    // user is in control group (variant 0)
} else {
    // user is in treatment group
}
```

### Treatment Variables

```dart
var defaultButtonColor = "red";
var buttonColor = context.getVariableValue("button.color", defaultButtonColor);
```

### Peek at Treatment Variants

Although generally not recommended, it is sometimes necessary to peek at a treatment or variable without triggering an exposure. The SDK provides `peekTreatment()` for that purpose.

```dart
int treatment = context.peekTreatment("exp_test_experiment");

if (treatment == 0) {
    // user is in control group (variant 0)
} else {
    // user is in treatment group
}
```

#### Peeking at Variables

```dart
var buttonColor = context.peekVariableValue("button.color", "red");
```

### Overriding Treatment Variants

During development, it is useful to force a treatment for an experiment. This can be achieved with `setOverride()` and/or `setOverrides()`. These methods can be called before the context is ready.

```dart
context.setOverride("exp_test_experiment", 1);

context.setOverrides({
    "exp_test_experiment": 1,
    "exp_another_experiment": 0,
});
```

## Advanced

### Context Attributes

The `setAttribute()` and `setAttributes()` methods can be called before the context is ready.

```dart
context.setAttribute("user_agent", "Mozilla/5.0...");

context.setAttributes({
    "customer_age": "new_customer",
});
```

### Custom Assignments

Custom assignments allow you to force a specific variant for a user in a particular experiment, while still recording the assignment as a regular exposure (unlike overrides, which are marked as overridden).

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

Sometimes it is necessary to ensure all events have been published to the A/B Smartly collector before proceeding. You can explicitly call `publish()`.

```dart
await context.publish();
```

### Finalizing

The `close()` method will ensure all events have been published to the A/B Smartly collector, like `publish()`, and will also "seal" the context, throwing an error if any method that could generate an event is called.

```dart
await context.close();
```

### Custom Event Logger

The SDK can be instantiated with an event logger used for all contexts. In addition, an event logger can be specified when creating a particular context in the `ContextConfig`.

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

Usage:

```dart
// For all contexts, during SDK initialization
final sdkConfig = ABSmartlyConfig.create(
    client: Client.create(clientConfig),
    contextEventLogger: CustomEventLogger(),
);

final ABSmartly sdk = ABSmartly(sdkConfig);

// OR for a particular context
final contextConfig = ContextConfig.create(
    units: {"session_id": "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"},
    contextEventLogger: CustomEventLogger(),
);
```

**Event Types**

| Event      | When                                               | Data                                      |
| ---------- | -------------------------------------------------- | ----------------------------------------- |
| `error`    | Context receives an error                          | Error object                              |
| `ready`    | Context turns ready                                | `ContextData` used to initialize          |
| `refresh`  | `refresh()` method succeeds                        | `ContextData` used to refresh             |
| `publish`  | `publish()` method succeeds                        | `PublishEvent` sent to collector          |
| `exposure` | `getTreatment()` succeeds on first exposure        | `Exposure` enqueued for publishing        |
| `goal`     | `track()` method succeeds                          | `GoalAchievement` enqueued for publishing |
| `close`    | `close()` method succeeds the first time           | `null`                                    |

## Platform-Specific Examples

### Using in a Dart CLI Application

```dart
import 'package:absmartly_dart/absmartly_dart.dart';

void main() async {
    final clientConfig = ClientConfig.create(
        endpoint: "https://your-company.absmartly.io/v1",
        apiKey: "YOUR-API-KEY",
        application: "cli-tool",
        environment: "production",
    );

    final sdkConfig = ABSmartlyConfig.create(
        client: Client.create(clientConfig),
    );

    final ABSmartly sdk = ABSmartly(sdkConfig);

    final contextConfig = ContextConfig.create(
        units: {"user_id": "user-123"},
    );

    final Context context = await sdk.createContext(contextConfig).waitUntilReady();

    int treatment = context.getTreatment("exp_new_algorithm");

    if (treatment == 0) {
        print("Running standard algorithm");
    } else {
        print("Running new algorithm");
    }

    context.track("process_complete", {
        "duration_ms": 1500,
    });

    await context.close();
}
```

### Using in a Server-Side Dart Application

```dart
import 'dart:io';
import 'package:absmartly_dart/absmartly_dart.dart';

late ABSmartly sdk;

void initSDK() {
    final clientConfig = ClientConfig.create(
        endpoint: "https://your-company.absmartly.io/v1",
        apiKey: "YOUR-API-KEY",
        application: "api-server",
        environment: "production",
    );

    final sdkConfig = ABSmartlyConfig.create(
        client: Client.create(clientConfig),
    );

    sdk = ABSmartly(sdkConfig);
}

Future<void> handleRequest(HttpRequest request) async {
    final String sessionId = request.cookies
        .firstWhere((c) => c.name == "session_id", orElse: () => Cookie("session_id", ""))
        .value;

    final contextConfig = ContextConfig.create(
        units: {"session_id": sessionId},
    );

    final Context context = await sdk.createContext(contextConfig).waitUntilReady();

    int treatment = context.getTreatment("exp_api_response_format");

    if (treatment == 0) {
        request.response.write('{"format": "standard"}');
    } else {
        request.response.write('{"format": "enhanced"}');
    }

    await context.close();
    await request.response.close();
}
```

### Using with Flutter (via absmartly_dart)

While the [`absmartly_sdk`](https://pub.dev/packages/absmartly_sdk) package is recommended for Flutter applications, you can also use this SDK directly:

```dart
import 'package:flutter/material.dart';
import 'package:absmartly_dart/absmartly_dart.dart';

class ExperimentWidget extends StatefulWidget {
    @override
    _ExperimentWidgetState createState() => _ExperimentWidgetState();
}

class _ExperimentWidgetState extends State<ExperimentWidget> {
    late ABSmartly sdk;
    Context? abContext;
    int treatment = 0;

    @override
    void initState() {
        super.initState();
        initABSmartly();
    }

    Future<void> initABSmartly() async {
        final clientConfig = ClientConfig.create(
            endpoint: "https://your-company.absmartly.io/v1",
            apiKey: "YOUR-API-KEY",
            application: "flutter-app",
            environment: "production",
        );

        final sdkConfig = ABSmartlyConfig.create(
            client: Client.create(clientConfig),
        );

        sdk = ABSmartly(sdkConfig);

        final contextConfig = ContextConfig.create(
            units: {"device_id": "device-unique-id"},
        );

        abContext = await sdk.createContext(contextConfig).waitUntilReady();

        setState(() {
            treatment = abContext!.getTreatment("exp_button_style");
        });
    }

    @override
    void dispose() {
        abContext?.close();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        if (treatment == 0) {
            return ElevatedButton(
                onPressed: () {},
                child: Text("Standard Button"),
            );
        } else {
            return OutlinedButton(
                onPressed: () {},
                child: Text("New Button Style"),
            );
        }
    }
}
```

## Flutter Users

For Flutter applications, consider using the [`absmartly_sdk`](https://pub.dev/packages/absmartly_sdk) package, which wraps this SDK and may include Flutter-specific features in the future.

## Documentation

- [Full Documentation](https://docs.absmartly.com/)
- [API Reference](https://pub.dev/documentation/absmartly_dart/latest/)

## About A/B Smartly

**A/B Smartly** is the leading provider of state-of-the-art, on-premises, full-stack experimentation platforms for engineering and product teams that want to confidently deploy features as fast as they can develop them.
A/B Smartly's real-time analytics helps engineering and product teams ensure that new features will improve the customer experience without breaking or degrading performance and/or business metrics.

### Have a look at our growing list of clients and SDKs:
- [Java SDK](https://www.github.com/absmartly/java-sdk)
- [JavaScript SDK](https://www.github.com/absmartly/javascript-sdk)
- [PHP SDK](https://www.github.com/absmartly/php-sdk)
- [Swift SDK](https://www.github.com/absmartly/swift-sdk)
- [Vue2 SDK](https://www.github.com/absmartly/vue2-sdk)
- [Vue3 SDK](https://www.github.com/absmartly/vue3-sdk)
- [React SDK](https://www.github.com/absmartly/react-sdk)
- [Angular SDK](https://www.github.com/absmartly/angular-sdk)
- [Android SDK](https://www.github.com/absmartly/android-sdk)
- [Python3 SDK](https://www.github.com/absmartly/python3-sdk)
- [Go SDK](https://www.github.com/absmartly/go-sdk)
- [Ruby SDK](https://www.github.com/absmartly/ruby-sdk)
- [.NET SDK](https://www.github.com/absmartly/dotnet-sdk)
- [Dart SDK](https://www.github.com/absmartly/dart-sdk) (this package)
- [Flutter SDK](https://www.github.com/absmartly/flutter-sdk)
