# Flutter SDK Widgets Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Flutter-specific widgets to the `absmartly_sdk` package for easy A/B testing integration in Flutter apps.

**Architecture:** InheritedWidget-based provider pattern with declarative Treatment widgets. Silent fallback to control on errors. Configurable loading behavior with timeout.

**Tech Stack:** Flutter, Dart, absmartly_dart (core SDK)

---

## Design Decisions

### 1. Package Structure
- **absmartly_sdk** (flutter_sdk) - Core Flutter widgets (this implementation)
- **absmartly_sdk_hooks** (future) - Optional flutter_hooks support

### 2. Provider Pattern
Single nestable provider with convenient factory:
- `ABSmartlyProvider.create()` - Simple setup (90% of users)
- `ABSmartlyProvider()` - Advanced setup with custom SDK/context

### 3. Treatment Widgets
Multiple patterns for flexibility:
- `Treatment` - Map-based variants
- `TreatmentBuilder` - Builder pattern with callback
- `TreatmentVariant` - React-style named children

### 4. Loading Behavior
Configurable at Provider level, overridable at Treatment level:
- `LoadingBehavior.placeholder` - Show empty SizedBox, fallback to control after timeout
- `LoadingBehavior.control` - Show control immediately (risk of flicker)

### 5. Error Handling
Silent fallback to control variant (0) on all errors. A/B testing should be invisible to end users.

---

## API Design

### LoadingBehavior Enum

```dart
enum LoadingBehavior {
  /// Show empty SizedBox while loading, fallback to control after timeout
  placeholder,

  /// Show control variant immediately (may cause flicker if variant changes)
  control,
}
```

### ABSmartlyProvider

```dart
class ABSmartlyProvider extends StatefulWidget {
  /// Simple setup - creates SDK and context internally
  factory ABSmartlyProvider.create({
    required String endpoint,
    required String apiKey,
    required String environment,
    required String application,
    required Map<String, String> units,
    LoadingBehavior defaultLoadingBehavior = LoadingBehavior.placeholder,
    Duration readyTimeout = const Duration(seconds: 3),
    required Widget child,
  });

  /// Advanced setup - provide custom SDK and context
  const ABSmartlyProvider({
    required this.sdk,
    required this.context,
    this.defaultLoadingBehavior = LoadingBehavior.placeholder,
    this.readyTimeout = const Duration(seconds: 3),
    required this.child,
  });

  /// Access the nearest ABSmartlyProvider
  static ABSmartlyData of(BuildContext context, {bool listen = true});

  /// Access without throwing if not found
  static ABSmartlyData? maybeOf(BuildContext context, {bool listen = true});
}
```

### ABSmartlyData (provided via InheritedWidget)

```dart
class ABSmartlyData {
  final ABSmartly sdk;
  final Context context;
  final LoadingBehavior defaultLoadingBehavior;
  final Duration readyTimeout;

  bool get isReady;
  bool get isFailed;

  /// Reset context with new units (e.g., on login/logout)
  Future<void> resetContext({required Map<String, String> units});
}
```

### Treatment Widget (Map-based)

```dart
class Treatment extends StatelessWidget {
  const Treatment({
    required this.name,
    required this.variants,
    this.loading,
    this.context,
    super.key,
  });

  /// Experiment name
  final String name;

  /// Map of variant index to widget
  /// Key 0 = control, 1+ = variants
  final Map<int, Widget> variants;

  /// Optional loading widget (overrides provider default)
  final Widget? loading;

  /// Optional specific context (defaults to nearest provider)
  final Context? context;
}
```

### TreatmentBuilder Widget

```dart
class TreatmentBuilder extends StatelessWidget {
  const TreatmentBuilder({
    required this.name,
    required this.builder,
    this.loading,
    this.context,
    super.key,
  });

  /// Experiment name
  final String name;

  /// Builder callback with variant number and variables
  final Widget Function(BuildContext context, int variant, Map<String, dynamic> variables) builder;

  /// Optional loading widget
  final Widget? loading;

  /// Optional specific context
  final Context? context;
}
```

### TreatmentVariant (for use with TreatmentSwitch)

```dart
class TreatmentVariant extends StatelessWidget {
  const TreatmentVariant({
    required this.variant,
    required this.child,
    super.key,
  });

  /// Variant index (0 = control, 1+ = variants) or letter ('A', 'B', etc.)
  final dynamic variant;

  final Widget child;
}

class TreatmentSwitch extends StatelessWidget {
  const TreatmentSwitch({
    required this.name,
    required this.children,
    this.loading,
    this.context,
    super.key,
  });

  /// Experiment name
  final String name;

  /// List of TreatmentVariant widgets
  final List<TreatmentVariant> children;

  /// Optional loading widget
  final Widget? loading;

  /// Optional specific context
  final Context? context;
}
```

---

## Usage Examples

### Basic Setup

```dart
void main() {
  runApp(
    ABSmartlyProvider.create(
      endpoint: 'https://your-company.absmartly.io/v1',
      apiKey: 'your-api-key',
      environment: 'production',
      application: 'my-flutter-app',
      units: {'user_id': '12345'},
      child: MyApp(),
    ),
  );
}
```

### Treatment with Map

```dart
Treatment(
  name: 'checkout_experiment',
  variants: {
    0: OldCheckoutButton(),
    1: NewCheckoutButton(),
    2: AnotherVariantButton(),
  },
)
```

### TreatmentBuilder

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

### TreatmentSwitch with TreatmentVariant

```dart
TreatmentSwitch(
  name: 'hero_experiment',
  children: [
    TreatmentVariant(variant: 0, child: ClassicHero()),
    TreatmentVariant(variant: 1, child: ModernHero()),
    TreatmentVariant(variant: 'C', child: MinimalHero()), // Can use letters
  ],
)
```

### Custom Loading Widget

```dart
Treatment(
  name: 'banner_experiment',
  loading: ShimmerBanner(), // Custom loading state
  variants: {
    0: ControlBanner(),
    1: NewBanner(),
  },
)
```

### Accessing Context Directly

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final absmartly = ABSmartlyProvider.of(context);

    return ElevatedButton(
      onPressed: () {
        // Track a goal
        absmartly.context.track('button_clicked', {'button_id': 'cta'});
      },
      child: Text('Click me'),
    );
  }
}
```

### Reset Context on Login

```dart
void onUserLogin(String userId) {
  ABSmartlyProvider.of(context, listen: false)
    .resetContext(units: {'user_id': userId});
}
```

---

## File Structure

```
packages/flutter_sdk/lib/
├── absmartly_sdk.dart              # Main export (updated)
└── src/
    ├── widgets/
    │   ├── absmartly_provider.dart # ABSmartlyProvider + ABSmartlyData
    │   ├── treatment.dart          # Treatment widget
    │   ├── treatment_builder.dart  # TreatmentBuilder widget
    │   └── treatment_switch.dart   # TreatmentSwitch + TreatmentVariant
    ├── loading_behavior.dart       # LoadingBehavior enum
    └── inherited_absmartly.dart    # InheritedWidget implementation
```

---

## Implementation Tasks

### Task 1: Create LoadingBehavior enum
**Files:** Create `packages/flutter_sdk/lib/src/loading_behavior.dart`

### Task 2: Create InheritedABSmartly widget
**Files:** Create `packages/flutter_sdk/lib/src/inherited_absmartly.dart`

### Task 3: Create ABSmartlyProvider widget
**Files:** Create `packages/flutter_sdk/lib/src/widgets/absmartly_provider.dart`

### Task 4: Create Treatment widget
**Files:** Create `packages/flutter_sdk/lib/src/widgets/treatment.dart`

### Task 5: Create TreatmentBuilder widget
**Files:** Create `packages/flutter_sdk/lib/src/widgets/treatment_builder.dart`

### Task 6: Create TreatmentSwitch and TreatmentVariant widgets
**Files:** Create `packages/flutter_sdk/lib/src/widgets/treatment_switch.dart`

### Task 7: Update main export file
**Files:** Modify `packages/flutter_sdk/lib/absmartly_sdk.dart`

### Task 8: Write unit tests
**Files:** Create test files in `packages/flutter_sdk/test/`

### Task 9: Update README with widget documentation
**Files:** Modify `packages/flutter_sdk/README.md`

---

## Loading Behavior Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Treatment Widget                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐                                        │
│  │ Context Ready?  │                                        │
│  └────────┬────────┘                                        │
│           │                                                  │
│     ┌─────┴─────┐                                           │
│     │           │                                           │
│    YES          NO                                          │
│     │           │                                           │
│     ▼           ▼                                           │
│  ┌──────┐   ┌──────────────────┐                           │
│  │ Show │   │ Has loading prop?│                           │
│  │Variant│   └────────┬────────┘                           │
│  └──────┘        ┌────┴────┐                               │
│                  │         │                                │
│                 YES        NO                               │
│                  │         │                                │
│                  ▼         ▼                                │
│            ┌─────────┐  ┌─────────────────────┐            │
│            │  Show   │  │ Provider behavior?  │            │
│            │ loading │  └─────────┬───────────┘            │
│            │ widget  │       ┌────┴────┐                   │
│            └─────────┘       │         │                   │
│                         placeholder  control               │
│                              │         │                   │
│                              ▼         ▼                   │
│                        ┌─────────┐ ┌─────────┐            │
│                        │SizedBox │ │ Show    │            │
│                        │+ timeout│ │ Control │            │
│                        └────┬────┘ └─────────┘            │
│                             │                              │
│                      Timeout expired?                      │
│                             │                              │
│                            YES                             │
│                             │                              │
│                             ▼                              │
│                       ┌─────────┐                          │
│                       │  Show   │                          │
│                       │ Control │                          │
│                       └─────────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
