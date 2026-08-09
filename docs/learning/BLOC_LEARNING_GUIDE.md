# BLoC Pattern Learning Guide

## What is BLoC?

**BLoC (Business Logic Component)** is a state management pattern that separates business logic from UI. It makes your code more testable, maintainable, and easier to understand.

## BLoC Architecture

```
┌─────────────┐
│    UI       │  (Widgets/Screens)
└──────┬──────┘
       │ Events (User Actions)
       ▼
┌─────────────┐
│    BLoC     │  (Business Logic)
└──────┬──────┘
       │ States (UI Updates)
       ▼
┌─────────────┐
│    UI       │  (Rebuilds based on state)
└─────────────┘
```

## Key Components

### 1. **Events** (What the user does)
- User actions like button taps, form submissions
- Examples: `CreateWalletEvent`, `PasscodeDigitEntered`, `TabSelectedEvent`

### 2. **States** (What the UI should show)
- Represents the current condition of your feature
- Examples: `WalletLoading`, `WalletCreated`, `PasscodeEntering`

### 3. **BLoC** (The brain)
- Processes events and emits states
- Contains all business logic
- Examples: `WalletBloc`, `PasscodeBloc`, `HomepageBloc`

## How It Works

1. **User Action** → Dispatch Event
   ```dart
   context.read<WalletBloc>().add(CreateWalletEvent());
   ```

2. **BLoC Processes** → Emits State
   ```dart
   // In WalletBloc
   on<CreateWalletEvent>(_onCreateWallet);
   
   Future<void> _onCreateWallet(...) async {
     emit(WalletLoading());  // Show loading
     final wallet = await _createWallet();
     emit(WalletCreated(wallet));  // Show wallet
   }
   ```

3. **UI Listens** → Rebuilds
   ```dart
   BlocBuilder<WalletBloc, WalletState>(
     builder: (context, state) {
       if (state is WalletLoading) return CircularProgressIndicator();
       if (state is WalletCreated) return WalletDisplay(state.wallet);
       return Container();
     },
   )
   ```

## Widgets You'll Use

### `BlocBuilder`
- Rebuilds UI when state changes
- Use for displaying data

```dart
BlocBuilder<WalletBloc, WalletState>(
  builder: (context, state) {
    // Build UI based on state
  },
)
```

### `BlocListener`
- Listens to state changes for side effects
- Use for navigation, snackbars, dialogs

```dart
BlocListener<WalletBloc, WalletState>(
  listener: (context, state) {
    if (state is WalletSaved) {
      Navigator.push(...);  // Navigate
    }
  },
  child: YourWidget(),
)
```

### `BlocConsumer`
- Combines `BlocBuilder` + `BlocListener`
- Use when you need both UI updates and side effects

```dart
BlocConsumer<WalletBloc, WalletState>(
  listener: (context, state) {
    // Side effects (navigation, etc.)
  },
  builder: (context, state) {
    // Build UI
  },
)
```

## Example: Wallet Creation Flow

### Before (setState):
```dart
class _CreateWalletScreenState extends State<CreateWalletScreen> {
  Wallet? _wallet;
  bool _isLoading = true;
  
  Future<void> _generateWallet() async {
    setState(() => _isLoading = true);
    final wallet = await _createWallet();
    setState(() {
      _wallet = wallet;
      _isLoading = false;
    });
  }
}
```

### After (BLoC):
```dart
// In initState
context.read<WalletBloc>().add(CreateWalletEvent());

// In build
BlocBuilder<WalletBloc, WalletState>(
  builder: (context, state) {
    if (state is WalletLoading) return LoadingWidget();
    if (state is WalletCreated) return WalletWidget(state.wallet);
    return Container();
  },
)
```

## Benefits

1. **Separation of Concerns**: UI and business logic are separate
2. **Testability**: Easy to test business logic without UI
3. **Predictability**: State changes are explicit and traceable
4. **Reusability**: BLoCs can be shared across multiple widgets
5. **Debugging**: Easy to track state changes with BlocObserver

## Files Created

### Wallet BLoC
- `wallet_event.dart` - Events (CreateWalletEvent, SaveWalletEvent, etc.)
- `wallet_state.dart` - States (WalletLoading, WalletCreated, etc.)
- `wallet_bloc.dart` - Business logic

### Passcode BLoC
- `passcode_event.dart` - Events (PasscodeDigitEntered, VerifyPasscodeEvent, etc.)
- `passcode_state.dart` - States (PasscodeEntering, PasscodeVerified, etc.)
- `passcode_bloc.dart` - Business logic

### Homepage BLoC
- `homepage_event.dart` - Events (TabSelectedEvent)
- `homepage_state.dart` - States (HomepageInitial)
- `homepage_bloc.dart` - Business logic

## Best Practices

1. **One BLoC per feature** - Don't put everything in one BLoC
2. **Immutable states** - Use `equatable` for state comparison
3. **Pure functions** - BLoC methods should be predictable
4. **Error handling** - Always have error states
5. **Loading states** - Show loading indicators during async operations

## Next Steps

- Add `BlocObserver` for logging state changes
- Add unit tests for BLoCs
- Consider using `BlocProvider.value` for dependency injection
- Add `BlocProvider` at feature level instead of app level for better performance
