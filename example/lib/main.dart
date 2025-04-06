import 'package:absmartly_sdk/ab_smartly.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:absmartly_sdk/client_config.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/helper/funtions.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const AbSmartlyScreen(),
    );
  }
}

class AbSmartlyScreen extends StatefulWidget {
  const AbSmartlyScreen({Key? key}) : super(key: key);

  @override
  State<AbSmartlyScreen> createState() => _AbSmartlyScreenState();
}

class _AbSmartlyScreenState extends State<AbSmartlyScreen> {
  @override
  void initState() {
    super.initState();
  }

  String res = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          initData();
        },
        child: const Icon(Icons.send),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Text(res),
          ),
        ),
      ),
    );
  }

  initData() async {
    final ClientConfig clientConfig = ClientConfig()
      ..setEndpoint(const String.fromEnvironment("ABSMARTLY_ENDPOINT"))
      ..setAPIKey(const String.fromEnvironment("ABSMARTLY_API_KEY"))
      ..setApplication(const String.fromEnvironment("ABSMARTLY_APPLICATION"))
      ..setEnvironment(const String.fromEnvironment("ABSMARTLY_ENVIRONMENT"));

    final ABSmartlyConfig sdkConfig =
        ABSmartlyConfig.create().setClient(Client.create(clientConfig));
    final ABSmartly sdk = ABSmartly(sdkConfig);
    final ContextConfig contextConfig = ContextConfig.create()
      ..setUnit("user_id", "123456");

    contextConfig.setContextEventLogger(CustomEventLogger());

    final Context context =
        await sdk.createContext(contextConfig).waitUntilReady();

    context.refresh();

    final int treatment = context.getTreatment("exp_test_ab");

    final Map<String, dynamic> properties = {};
    properties["value"] = 125;
    properties["fee"] = 125;

    context.setCustomAssignment("experimentName", 1);
    context.setCustomAssignments({"experimentName": 1});

    context.getCustomAssignment("experimentName");

    context.setAttribute("attribute", 1);
    context.setAttributes(
      {
        "attribute": 1,
      },
    );

    context.track("payment", properties);

    context.close();
    res = "Variant ${treatment.toString()}";
    setState(() {});
    Helper.response = null;
  }
}

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
