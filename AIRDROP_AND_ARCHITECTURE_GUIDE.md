# Airdrop Request Flow & Clean Architecture Guide

## How Airdrop Request Works

### The Complete Flow

```
User Taps "Request Test SOL"
    ↓
HomepageScreen._requestAirdrop()
    ↓
WalletBloc.add(RequestAirdropEvent(address))
    ↓
WalletBloc._onRequestAirdrop()
    ↓
SolanaRpcDataSource.requestAirdrop(address, lamports)
    ↓
HTTP POST to https://api.devnet.solana.com
    ↓
Solana Devnet processes airdrop
    ↓
Returns transaction signature
    ↓
WalletBloc emits AirdropRequested state
    ↓
HomepageScreen (BlocListener) shows success message
    ↓
WalletBloc fetches updated balance
    ↓
WalletBloc emits BalanceFetched state
    ↓
HomepageScreen (BlocBuilder) updates UI with new balance
```

### Step-by-Step Breakdown

#### 1. **User Action** (Presentation Layer)
```dart
// lib/features/homepage/presentation/screens/homepage_screen.dart
void _requestAirdrop() {
  if (_walletAddress != null) {
    // Dispatch event to BLoC
    context.read<WalletBloc>().add(
      RequestAirdropEvent(address: _walletAddress!),
    );
  }
}
```

#### 2. **Event** (Presentation Layer)
```dart
// lib/features/wallet/presentation/bloc/wallet_event.dart
class RequestAirdropEvent extends WalletEvent {
  final String address;
  final int lamports; // 1 SOL = 1,000,000,000 lamports
  
  const RequestAirdropEvent({
    required this.address,
    this.lamports = 1000000000,
  });
}
```

#### 3. **BLoC Handler** (Presentation Layer)
```dart
// lib/features/wallet/presentation/bloc/wallet_bloc.dart
Future<void> _onRequestAirdrop(
  RequestAirdropEvent event,
  Emitter<WalletState> emit,
) async {
  emit(const WalletLoading()); // Show loading
  
  try {
    // Call data source (Data Layer)
    final signature = await _rpcDataSource.requestAirdrop(
      event.address,
      event.lamports,
    );
    
    // Emit success state
    emit(AirdropRequested(
      transactionSignature: signature,
      address: event.address,
    ));
    
    // Fetch updated balance
    final balance = await _rpcDataSource.getBalance(event.address);
    emit(BalanceFetched(balance: balance, address: event.address));
  } catch (e) {
    emit(WalletError(e.toString()));
  }
}
```

#### 4. **RPC Data Source** (Data Layer)
```dart
// lib/features/wallet/data/datasource/solana_rpc_datasource.dart
Future<String> requestAirdrop(String address, int lamports) async {
  final requestBody = jsonEncode({
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'requestAirdrop',
    'params': [address, lamports],
  });

  final response = await client.post(
    Uri.parse(rpcUrl), // https://api.devnet.solana.com
    headers: {'Content-Type': 'application/json'},
    body: requestBody,
  );

  // Returns transaction signature
  return data['result'] as String;
}
```

#### 5. **State Update** (Presentation Layer)
```dart
// lib/features/homepage/presentation/screens/homepage_screen.dart
BlocListener<WalletBloc, WalletState>(
  listener: (context, state) {
    if (state is AirdropRequested) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  },
  builder: (context, state) {
    if (state is BalanceFetched) {
      // Update UI with new balance
      return Text('${state.balanceInSol} SOL');
    }
  },
)
```

---

## Clean Architecture Structure

### Overview

Clean Architecture separates code into **layers** with clear responsibilities:

```
┌─────────────────────────────────────┐
│     PRESENTATION LAYER              │  ← UI, BLoC, Screens
│  (What user sees and interacts with)│
├─────────────────────────────────────┤
│        DOMAIN LAYER                 │  ← Business Logic, Entities
│  (Core business rules - no deps)    │
├─────────────────────────────────────┤
│         DATA LAYER                  │  ← APIs, Database, Storage
│  (How data is fetched/stored)      │
└─────────────────────────────────────┘
```

### Layer Breakdown

#### 1. **Presentation Layer** 
**Location:** `lib/features/[feature]/presentation/`

**What goes here:**
- ✅ UI widgets and screens
- ✅ BLoC files (bloc, events, states)
- ✅ Widgets specific to this feature
- ✅ UI-related logic

**Structure:**
```
presentation/
├── bloc/
│   ├── [feature]_bloc.dart      # Business logic handler
│   ├── [feature]_event.dart     # User actions
│   └── [feature]_state.dart      # UI states
├── screens/
│   └── [feature]_screen.dart     # Full screen widgets
└── widgets/
    └── [feature]_widget.dart     # Reusable widgets
```

**Example - Airdrop:**
- `wallet_bloc.dart` - Handles `RequestAirdropEvent`
- `wallet_event.dart` - `RequestAirdropEvent` definition
- `wallet_state.dart` - `AirdropRequested`, `BalanceFetched` states
- `homepage_screen.dart` - UI that calls airdrop

**When to use:**
- User interactions (button taps, form submissions)
- UI state management (loading, error, success)
- Navigation logic
- Displaying data to users

---

#### 2. **Domain Layer**
**Location:** `lib/features/[feature]/domain/`

**What goes here:**
- ✅ Business entities (pure Dart classes)
- ✅ Repository interfaces (abstract classes)
- ✅ Use cases (business logic)
- ❌ NO external dependencies (no HTTP, no storage, no UI)

**Structure:**
```
domain/
├── entities/
│   └── [entity].dart          # Pure data classes
├── repositories/
│   └── [feature]_repository.dart  # Abstract interface
└── usecases/
    └── [action]_usecase.dart   # Business logic
```

**Example - Wallet:**
- `entities/wallet.dart` - Wallet data structure
- `repositories/wallet_repository.dart` - Interface defining what wallet operations exist
- `usecases/create_wallet.dart` - Business logic for creating wallet

**When to use:**
- Define what your feature can do (interfaces)
- Core business rules
- Data models that don't depend on external libraries
- Use cases that orchestrate repository calls

**For Airdrop:**
- Could add: `usecases/request_airdrop_usecase.dart` (if you want to encapsulate the logic)
- Currently handled directly in BLoC, which is also fine for simple operations

---

#### 3. **Data Layer**
**Location:** `lib/features/[feature]/data/`

**What goes here:**
- ✅ API calls (HTTP requests)
- ✅ Database operations
- ✅ Local storage
- ✅ Data models (with serialization)
- ✅ Repository implementations

**Structure:**
```
data/
├── datasource/
│   ├── [feature]_local_datasource.dart    # Local storage
│   └── [feature]_remote_datasource.dart   # API calls
├── model/
│   └── [feature]_model.dart               # Data models
└── repositories/
    └── [feature]_repository_impl.dart     # Implements domain interface
```

**Example - Airdrop:**
- `datasource/solana_rpc_datasource.dart` - Makes HTTP calls to Solana RPC
- Handles JSON encoding/decoding
- Network communication

**When to use:**
- Making API calls
- Reading/writing to database
- Secure storage operations
- Data transformation (JSON, models)
- Implementing repository interfaces from domain layer

---

### Core Layer
**Location:** `lib/core/`

**What goes here:**
- ✅ Shared constants
- ✅ Error classes
- ✅ Utilities
- ✅ Base classes
- ✅ Network configuration

**Structure:**
```
core/
├── constant/
│   ├── network.dart          # RPC URLs
│   └── solana_path.dart      # Derivation paths
├── error/
│   ├── exception.dart        # Custom exceptions
│   └── failures.dart         # Error classes
└── router/
    └── app_router.dart        # Navigation
```

**Example - Airdrop:**
- `constant/network.dart` - Contains `solanaUrl = 'https://api.devnet.solana.com'`

**When to use:**
- Constants used across multiple features
- Shared error handling
- Base classes
- Configuration values

---

## Decision Tree: Where Does My Code Go?

### Is it user-facing UI?
→ **Presentation Layer** (`presentation/screens/` or `presentation/widgets/`)

### Is it state management (BLoC)?
→ **Presentation Layer** (`presentation/bloc/`)

### Is it a business rule or core logic?
→ **Domain Layer** (`domain/usecases/`)

### Is it a data model?
- Pure data, no external deps? → **Domain Layer** (`domain/entities/`)
- Needs JSON serialization? → **Data Layer** (`data/model/`)

### Is it an API call or network request?
→ **Data Layer** (`data/datasource/`)

### Is it database or local storage?
→ **Data Layer** (`data/datasource/`)

### Is it implementing a repository interface?
→ **Data Layer** (`data/repositories/`)

### Is it a constant or configuration?
→ **Core Layer** (`core/constant/`)

### Is it shared across multiple features?
→ **Core Layer** (`core/`)

---

## Airdrop Implementation Breakdown

### Files Involved

#### 1. **Event Definition** (Presentation)
**File:** `lib/features/wallet/presentation/bloc/wallet_event.dart`
```dart
class RequestAirdropEvent extends WalletEvent {
  final String address;
  final int lamports;
  // ...
}
```
**Why here?** Events represent user actions, which are part of the presentation layer.

#### 2. **State Definition** (Presentation)
**File:** `lib/features/wallet/presentation/bloc/wallet_state.dart`
```dart
class AirdropRequested extends WalletState { ... }
class BalanceFetched extends WalletState { ... }
```
**Why here?** States represent UI conditions, part of presentation.

#### 3. **BLoC Handler** (Presentation)
**File:** `lib/features/wallet/presentation/bloc/wallet_bloc.dart`
```dart
Future<void> _onRequestAirdrop(...) async {
  final signature = await _rpcDataSource.requestAirdrop(...);
  emit(AirdropRequested(...));
}
```
**Why here?** BLoC orchestrates business logic and manages state for UI.

#### 4. **RPC Data Source** (Data)
**File:** `lib/features/wallet/data/datasource/solana_rpc_datasource.dart`
```dart
Future<String> requestAirdrop(String address, int lamports) async {
  // HTTP POST to Solana RPC
}
```
**Why here?** This makes actual network calls, which is data layer responsibility.

#### 5. **Network Config** (Core)
**File:** `lib/core/constant/network.dart`
```dart
static const String solanaUrl = 'https://api.devnet.solana.com';
```
**Why here?** Configuration constant shared across the app.

#### 6. **UI Screen** (Presentation)
**File:** `lib/features/homepage/presentation/screens/homepage_screen.dart`
```dart
void _requestAirdrop() {
  context.read<WalletBloc>().add(RequestAirdropEvent(...));
}
```
**Why here?** User interface that triggers the action.

---

## Dependency Flow

```
Presentation Layer
    ↓ depends on
Domain Layer (interfaces)
    ↓ implemented by
Data Layer
    ↓ uses
Core Layer (constants, errors)
```

**Key Rule:** 
- **Domain** never depends on **Data** or **Presentation**
- **Presentation** depends on **Domain** (interfaces)
- **Data** implements **Domain** interfaces
- All layers can use **Core**

---

## Best Practices

### ✅ DO:
- Put UI code in `presentation/`
- Put API calls in `data/datasource/`
- Put business logic in `domain/usecases/` or BLoC
- Use interfaces in domain, implementations in data
- Keep domain layer pure (no external dependencies)

### ❌ DON'T:
- Put API calls in presentation layer
- Put UI code in data layer
- Make domain layer depend on data layer
- Mix concerns (e.g., HTTP calls in BLoC directly)

---

## Example: Adding a New Feature

Let's say you want to add "Send SOL" feature:

### 1. **Domain Layer** (Define what it does)
```
domain/
├── entities/
│   └── transaction.dart          # Transaction data
└── repositories/
    └── wallet_repository.dart     # Add: sendTransaction()
```

### 2. **Data Layer** (Implement how it works)
```
data/
├── datasource/
│   └── solana_rpc_datasource.dart  # Add: sendTransaction()
└── repositories/
    └── wallet_repository_impl.dart # Implement sendTransaction()
```

### 3. **Presentation Layer** (UI and state)
```
presentation/
├── bloc/
│   ├── wallet_event.dart          # Add: SendTransactionEvent
│   ├── wallet_state.dart          # Add: TransactionSent
│   └── wallet_bloc.dart           # Handle SendTransactionEvent
└── screens/
    └── send_screen.dart            # UI for sending
```

---

## Summary

**Airdrop Request:**
1. User taps button → **Presentation** (Screen)
2. Dispatch event → **Presentation** (BLoC Event)
3. Handle event → **Presentation** (BLoC)
4. Call data source → **Data** (RPC DataSource)
5. Make HTTP call → **Data** (Network request)
6. Return result → **Data** → **Presentation** (BLoC)
7. Emit state → **Presentation** (BLoC State)
8. Update UI → **Presentation** (Screen)

**Clean Architecture:**
- **Presentation** = What user sees and interacts with
- **Domain** = What the app can do (interfaces, business rules)
- **Data** = How data is fetched/stored (implementations)
- **Core** = Shared utilities and constants

This separation makes code:
- ✅ Testable (test each layer independently)
- ✅ Maintainable (changes isolated to one layer)
- ✅ Scalable (easy to add new features)
- ✅ Understandable (clear responsibilities)
