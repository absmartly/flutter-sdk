# A/B Smartly SDK

A/B Smartly Dart SDK

## Compatibility

The A/B Smartly Dart SDK is compatible with Dart versions
2.18.6 and later.

## Getting Started

### Install the SDK


To install the ABSmartly SDK, place the following in your `pubspec.yaml` and replace version with the latest SDK version available in pub.dev.

```pubspec.yaml
    ab_smartly: ^version
```

## Import and Initialize the SDK

Once the SDK is installed, it can be initialized in your project.

```

void main() async{
  final ClientConfig clientConfig = ClientConfig()
    ..setEndpoint("https://your-company.absmartly.io/v1")
    ..setAPIKey("YOUR API KEY")
    ..setApplication("website")
    ..setEnvironment("development");

  final ABSmartlyConfig sdkConfig = ABSmartlyConfig.create()
      .setClient(Client.create(clientConfig));
  final ABSmartly sdk = ABSmartly(sdkConfig);
}
```

**SDK Options**

| Config      | Type                                 | Required? |                 Default                 | Description                                                                                                                                                                   |
| :---------- | :----------------------------------- | :-------: | :-------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| endpoint    | `string`                             |  &#9989;  |               `undefined`               | The URL to your API endpoint. Most commonly `"your-company.absmartly.io"`                                                                                                     |
| apiKey      | `string`                             |  &#9989;  |               `undefined`               | Your API key which can be found on the Web Console.                                                                                                                           |
| environment | `"production"` or `"development"`    |  &#9989;  |               `undefined`               | The environment of the platform where the SDK is installed. Environments are created on the Web Console and should match the available environments in your infrastructure.   |
| application | `string`                             |  &#9989;  |               `undefined`               | The name of the application where the SDK is installed. Applications are created on the Web Console and should match the applications where your experiments will be running. |



### Using a Custom Event Logger

The A/B Smartly SDK can be instantiated with an event logger used for all
contexts. In addition, an event logger can be specified when creating a
particular context, in the `[CONTEXT_CONFIG_VARIABLE]`.

```
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
```

```
    contextConfig.setContextEventLogger(CustomEventLogger());
```

The data parameter depends on the type of event. Currently, the SDK logs the
following events:

| eventName    | when                                                    | data                                         |
| ------------ | ------------------------------------------------------- | -------------------------------------------- |
| `"error"`    | `Context` receives an error                             | error object thrown                          |
| `"ready"`    | `Context` turns ready                                   | data used to initialize the context          |
| `"refresh"`  | `Context.refresh()` method succeeds                     | data used to refresh the context             |
| `"publish"`  | `Context.publish()` method succeeds                     | data sent to the A/B Smartly event collector |
| `"exposure"` | `Context.treatment()` method succeeds on first exposure | exposure data enqueued for publishing        |
| `"goal"`     | `Context.track()` method succeeds                       | goal data enqueued for publishing            |
| `"finalize"` | `Context.finalize()` method succeeds the first time     | undefined                                    |

## Create a New Context Request

**Synchronously**

```
createNewContext() async{
  final ContextConfig contextConfig = ContextConfig.create()
      .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"); // a unique id identifying the user

  final Context? context = sdk.createContext(contextConfig)
      .waitUntilReady();

  if(context != null){
    print("context ready");
  }  
}

```

**Asynchronously**

```
createNewContext() async{
  final ContextConfig contextConfig = ContextConfig.create()
      .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"); // a unique id identifying the user

  final Context? context = await sdk.createContext(contextConfig)
      .waitUntilReady();

  if(context != null){
    print("context ready");
  }  
}

```

**With Prefetched Data**

```
    final ContextConfig contextConfig = ContextConfig.create()
        .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"); // a unique id identifying the user

    final Context context = sdk.createContext(contextConfig)
        .waitUntilReady();

    final ContextConfig anotherContextConfig = ContextConfig.create()
        .setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8"); // a unique id identifying the other user

    final Context anotherContext = sdk.createContextWith(anotherContextConfig, context.getData());
    assert(anotherContext.isReady()); // no need to wait

```

**Refreshing the Context with Fresh Experiment Data**

For long-running contexts, the context is usually created once when the application is first started. However, any experiments being tracked in your production code, but started after the context was created, will not be triggered. To mitigate this, we can use the    `setRefreshInterval()` method on the context config.

```
    final ContextConfig contextConfig = ContextConfig.create()
		.setUnit("session_id", "5ebf06d8cb5d8137290c4abb64155584fbdb64d8")
        .setRefreshInterval(TimeUnit.HOURS.toMillis(4)); // every 4 hours
```

Alternatively, the `refresh()` method can be called manually. The `refresh()` method pulls updated experiment data from the A/B Smartly collector and will trigger recently started experiments when `getTreatment()` is called again.

```
    context.refresh()
```

**Setting Extra Units**

You can add additional units to a context by calling the `setUnit()` or
`setUnits()` methods. These methods may be used, for example, when a user
logs in to your application and you want to use the new unit type in the
context.

Please note, you cannot override an already set unit type as that would be
a change of identity and would throw an exception. In this case, you must
create a new context instead. The `setUnit()` and
`setUnits()` methods can be called before the context is ready.

```
context.setUnit("db_user_id", "1000013");
context.setUnits({
		"db_user_id": "1000013"
    });
```

## Basic Usage

### Selecting A Treatment

```
    if((await context.getTreatment("exp_test_experiment")) == 0) {
        // user is in control group (variant 0)
    } else {
        // user is in treatment group
    }
```

### Treatment Variables

```
var defaultButtonColorValue = "red"

context.getVariableValue("experiment_name", defaultButtonColorValue)
```

### Peek at Treatment Variants

Although generally not recommended, it is sometimes necessary to peek at
a treatment or variable without triggering an exposure. The A/B Smartly
SDK provides a `peekTreatment()` method for that.

```
    final dynamic variable = context.getVariable("my_variable");
```

#### Peeking at variables

```
    var value = await ctx.peekTreatment("experimentName");
```

### Overriding Treatment Variants

During development, for example, it is useful to force a treatment for an experiment. This can be achieved with the `override()` and/or `overrides()` methods. The `setOverride()` and `setOverrides()` methods can be called before the context is ready.

```
    context.setOverride(experimentName, variant)
    context.setOverrides({
      "exp_test_experiment": 1,
      "exp_another_experiment": 0,
    });
```

## Advanced

### Context Attributes

Attributes are used to pass meta-data about the user and/or the request.
They can be used later in the Web Console to create segments or audiences.
They can be set using the `setAttribute()` or `setAttributes()`
methods, before or after the context is ready.

```
context.setAttribute("attribute", 1);
    context.setAttributes(
      {
        "attribute": 1,
      },
    );
```

### Custom Assignments

Sometimes it may be necessary to override the automatic selection of a
variant. For example, if you wish to have your variant chosen based on
data from an API call. This can be accomplished using the
`setCustomAssignment()` method.

```
    context.setCustomAssignment("experimentName", 1);
    context.setCustomAssignments({"experimentName": 1});
```

If you are running multiple experiments and need to choose different
custom assignments for each one, you can do so using the
`getCustomAssignment()` method.

```
    context.getCustomAssignment("experimentName");
```

### Publish

Sometimes it is necessary to ensure all events have been published to the A/B Smartly collector, before proceeding. You can explicitly call the `publish()` or `publishAsync()` methods.

```
    context.publish();
```

### Finalize


The `close()` and `closeAsync()` methods will ensure all events have been published to the A/B Smartly collector, like `publish()`, and will also "seal" the context, throwing an error if any method that could generate an event is called.

```
    context.close();
```

### Tracking Goals

Goals are created in the A/B Smartly web console.

``` 
     context.track("payment",{
      "item_count": 1,
      "total_amount": 1999.99
    });
```