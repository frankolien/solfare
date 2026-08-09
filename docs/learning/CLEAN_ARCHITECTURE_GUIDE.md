# Clean Architecture - How Everything Connects

> Clean Architecture is about **separation of concerns**.
> Each layer has ONE job and talks to other layers through clear boundaries.

---

## The Layers (From Outside In)

```
┌──────────────────────────────────────────────────┐
│  PRESENTATION LAYER                              │
│  (Screens, Widgets, BLoC)                        │
│  "What the user sees and does"                   │
├──────────────────────────────────────────────────┤
│  DOMAIN LAYER                                    │
│  (Entities, Repository Interfaces, Use Cases)    │
│  "What the app CAN do (the rules)"              │
├──────────────────────────────────────────────────┤
│  DATA LAYER                                      │
│  (DataSources, Models, Repository Implementations)│
│  "HOW data is fetched and stored"               │
└──────────────────────────────────────────────────┘
```

**The golden rule:** Dependencies point INWARD.
- Presentation knows about Domain
- Data knows about Domain
- Domain knows about NOTHING (it's the core, pure Dart, no imports from other layers)

---

## Each Layer Explained

---

### DATA LAYER - "The Workers"

This is where the actual work happens. API calls, database reads, file storage.

#### DataSource

**What it is:** A class that talks to ONE external system.

**Types:**
- **Remote DataSource** - talks to an API over the network (HTTP requests)
- **Local DataSource** - talks to on-device storage (secure storage, SQLite, shared preferences)

**In your project:**
- `solana_rpc_datasource.dart` - talks to Solana blockchain via HTTP (remote)
- `wallet_local_datasource.dart` - talks to flutter_secure_storage (local)
- `crypto_price_datasource.dart` - talks to CoinGecko API (remote)

**Rules:**
- One datasource per external system
- DataSources deal with raw data (JSON, Maps, Strings)
- They throw exceptions when things go wrong
- They know nothing about UI, BLoC, or business rules

**How to think about it:**
- "If I switched from CoinGecko to another price API, which file would I change?" -> Only the datasource
- "If I switched from secure storage to SQLite, which file would I change?" -> Only the local datasource

---

#### Model

**What it is:** A class that represents data as it comes from/goes to an external system.

**Responsibilities:**
- Convert FROM raw data (JSON -> Dart object): `fromJson()`
- Convert TO raw data (Dart object -> JSON): `toJson()`
- May extend the Domain Entity (adding serialization to a pure data class)

**In your project:**
- `wallet_model.dart` - knows how to convert wallet data to/from JSON for storage

**How Models relate to Entities:**
```
Entity (Domain)         Model (Data)
├── address             ├── address
├── publicKey           ├── publicKey
└── (no serialization)  ├── fromJson()    <- knows how to read from storage
                        └── toJson()      <- knows how to write to storage
```

The Model typically EXTENDS the Entity, adding the serialization methods.

**Rules:**
- Models live in the data layer only
- They handle all the messy conversion  (JlogicSON keys, type casting, null handling)
- The rest of the app uses Entities, not Models
- If the API response format changes, you only change the Model

---

#### Repository Implementation

**What it is:** The concrete class that implements the repository interface defined in the Domain layer.

**Responsibilities:**
- Call the right datasource(s)
- Convert Models to Entities
- Handle errors and convert exceptions to failures
- Decide: do I fetch from local cache or remote API?

**In your project:**
- `wallet_repository_impl.dart` - implements `WalletRepository` interface

**How it connects:**
```
Domain Layer defines:    WalletRepository (abstract - just method signatures)
Data Layer provides:     WalletRepositoryImpl (concrete - actual implementation)
                             |
                             ├── uses WalletLocalDataSource (for storage)
                             ├── uses SolanaRpcDataSource (for blockchain)
                             └── converts WalletModel <-> Wallet entity
```

**Rules:**
- Implements the interface from Domain
- Coordinates between multiple datasources if needed
- Converts raw data (Models) to clean data (Entities)
- Wraps errors into Failures (so the domain layer gets clean error types, not HTTP exceptions)

---

### DOMAIN LAYER - "The Rules"

This is the heart of your app. Pure business logic. No dependencies on Flutter, HTTP, databases, or UI.

#### Entity

**What it is:** A pure Dart class representing a core concept in your app.

**In your project:**
- `wallet.dart` - represents a Wallet (address, publicKey, mnemonic, etc.)

**Rules:**
- No imports from data or presentation layer
- No `fromJson()`, no Flutter imports, no HTTP
- Just properties and maybe some business logic methods
- This is what the rest of the app passes around

**Why separate from Model?**
- Entity = what a Wallet IS (the concept)
- Model = how a Wallet is STORED/TRANSMITTED (the format)
- If you change your API or database, Entity stays the same
- The Entity is the "truth", the Model is the "transport"

---

#### Repository (Interface / Abstract Class)

**What it is:** An abstract class that defines WHAT operations are possible, without saying HOW.

**In your project:**
- `wallet_repository.dart` - defines methods like `createWallet()`, `getWallet()`, `saveWallet()`

**What it looks like conceptually:**
```
"A wallet repository can:
  - create a wallet
  - save a wallet
  - get a stored wallet
  - delete a wallet

I don't care HOW. That's someone else's problem."
```

**Why is this just an interface?**
- The Domain layer doesn't know about databases, APIs, or storage
- It just says "these operations should exist"
- The Data layer provides the actual implementation
- This is called **Dependency Inversion** - the most important principle in clean architecture

**The power of this:**
- You could swap the entire data layer (switch databases, switch APIs) and the domain layer wouldn't change
- You can test the domain layer with a fake/mock repository
- The business rules are protected from infrastructure changes

---

#### Use Case

**What it is:** A class that represents ONE specific thing the app can do.

**In your project:**
- `create_wallet.dart` - the action of creating a new wallet
- `import_wallet.dart` - the action of importing an existing wallet
- `save_wallet.dart` - the action of saving a wallet

**What a use case does:**
- Takes input parameters
- Calls one or more repositories
- Applies business rules
- Returns a result

**Example flow:**
```
CreateWallet use case:
  1. Receive request to create wallet
  2. Call repository.createWallet()
  3. Return the created wallet OR a failure
```

**When to use a use case vs putting logic directly in BLoC:**
- **Use a use case** when the logic is complex, involves multiple steps, or multiple repositories
- **Skip the use case** when it's a simple pass-through (BLoC just calls repository directly)
- For a simple app, it's OK to skip use cases and call repositories from BLoC directly
- As the app grows, use cases help keep things organized

**Rules:**
- One use case = one action
- Use cases call repositories (through interfaces)
- Use cases contain business rules ("you can't send more than your balance")
- Use cases know nothing about UI, HTTP, or storage

---

### PRESENTATION LAYER - "The Face"

This is what the user interacts with. Screens, widgets, and BLoC state management.

#### Screens and Widgets
- Build the UI
- Send events to BLoC
- React to BLoC states
- No business logic, no API calls, no storage access

#### BLoC
- Receives events from UI
- Calls use cases or repositories
- Emits states for the UI
- Orchestrates the loading/success/error flow

(See BLOC_COMPLETE_GUIDE.md for the full BLoC breakdown)

---

## How They All Connect (The Full Picture)

```
USER TAPS "Create Wallet"
        |
        v
[SCREEN] sends CreateWalletEvent to BLoC
        |
        v
[BLOC] receives event, calls CreateWallet use case
        |
        v
[USE CASE] calls WalletRepository.createWallet()
        |
        v
[REPOSITORY INTERFACE] (Domain layer - abstract)
        |
        v  (implemented by)
[REPOSITORY IMPL] (Data layer - concrete)
        |
        ├──> calls WalletLocalDataSource.generateMnemonic()
        ├──> calls WalletLocalDataSource.deriveKeypair()
        ├──> calls WalletLocalDataSource.saveWallet()
        |
        v
[DATASOURCE] actually generates mnemonic, derives keys, stores in secure storage
        |
        v  (returns data back up the chain)
[REPOSITORY IMPL] converts WalletModel -> Wallet entity
        |
        v
[USE CASE] returns Wallet entity
        |
        v
[BLOC] emits WalletCreated(wallet) state
        |
        v
[SCREEN] sees WalletCreated state, navigates to success screen
```

---

## Dependency Injection (How Things Get Wired Together)

The layers need to be connected at app startup. This is called **dependency injection**.

**The wiring order:**
```
1. Create DataSources (they need nothing, or just a base URL / HTTP client)
      |
      v
2. Create Repository Implementations (they need DataSources)
      |
      v
3. Create Use Cases (they need Repository interfaces)
      |
      v
4. Create BLoCs (they need Use Cases or Repositories)
      |
      v
5. Provide BLoCs to the widget tree (BlocProvider)
```

**Why this order?**
- Each layer depends on the one below it
- You build from the bottom up
- The UI layer is last because it needs everything else to already exist

**In practice:**
- This wiring usually happens in `main.dart` or a dedicated injection file
- Packages like `get_it` can help manage this (service locator pattern)
- Or you can just create instances manually and pass them through constructors

---

## The Directory Structure (Your Project)

```
lib/
├── core/                           # Shared across all features
│   ├── constant/
│   │   ├── network.dart            # RPC URLs, API endpoints
│   │   └── solana_path.dart        # Derivation paths
│   ├── error/
│   │   ├── exception.dart          # Custom exceptions (data layer throws these)
│   │   └── failures.dart           # Failure classes (domain layer uses these)
│   └── router/
│       └── app_router.dart         # Navigation routes
│
├── features/
│   ├── wallet/                     # One feature = one folder
│   │   ├── data/                   # HOW (implementation)
│   │   │   ├── datasource/
│   │   │   │   ├── wallet_local_datasource.dart    # Secure storage operations
│   │   │   │   ├── solana_rpc_datasource.dart       # Blockchain API calls
│   │   │   │   └── crypto_price_datasource.dart     # Price API calls
│   │   │   ├── model/
│   │   │   │   └── wallet_model.dart                # JSON <-> Dart conversion
│   │   │   └── repositories/
│   │   │       └── wallet_repository_impl.dart      # Concrete implementation
│   │   │
│   │   ├── domain/                 # WHAT (interfaces and rules)
│   │   │   ├── entities/
│   │   │   │   └── wallet.dart                      # Pure wallet data class
│   │   │   ├── repositories/
│   │   │   │   └── wallet_repository.dart           # Abstract interface
│   │   │   └── usecases/
│   │   │       ├── create_wallet.dart               # Create wallet logic
│   │   │       ├── import_wallet.dart               # Import wallet logic
│   │   │       └── save_wallet.dart                 # Save wallet logic
│   │   │
│   │   └── presentation/          # UI (screens, state, widgets)
│   │       ├── bloc/
│   │       │   ├── wallet_bloc.dart
│   │       │   ├── wallet_event.dart
│   │       │   └── wallet_state.dart
│   │       ├── screens/
│   │       │   ├── create_wallet_screen.dart
│   │       │   ├── passcode_screen.dart
│   │       │   └── ... etc
│   │       └── widgets/
│   │
│   └── homepage/                   # Another feature
│       └── presentation/
│           ├── bloc/
│           └── screens/
│
├── shared/                         # Shared UI components
│   ├── screens/
│   └── widgets/
│
└── main.dart                       # App entry point + dependency wiring
```

---

## Exceptions vs Failures (Error Handling Strategy)

Clean architecture has a specific pattern for errors:

```
DATA LAYER                    DOMAIN LAYER
throws Exceptions    ->    catches and converts to Failures
(raw, technical)           (clean, meaningful)

ServerException              ServerFailure
CacheException               CacheFailure
NetworkException             NetworkFailure
```

**Why two types?**
- **Exceptions** (data layer) are technical: "HTTP 500", "Socket timeout", "Cache miss"
- **Failures** (domain layer) are meaningful: "Server is down", "No internet", "Data not found"
- The BLoC and UI deal with Failures, never raw Exceptions
- This keeps technical details from leaking into your UI code

**The Repository is the boundary:**
- DataSource throws an Exception
- Repository catches it
- Repository returns a Failure instead
- BLoC receives the Failure and emits an error state

---

## When To Skip Layers

Clean architecture can be overkill for simple features. Here's when it's OK to simplify:

**Skip Use Cases when:**
- The logic is just "call repository, return result"
- There are no business rules to enforce
- The BLoC can call the repository directly

**Skip the Repository pattern when:**
- There's only one data source (no local + remote coordination needed)
- The BLoC can call the datasource directly
- You're prototyping and will refactor later

**Never skip:**
- Separating UI from logic (always use BLoC or equivalent)
- Separating API calls from UI (never make HTTP calls from a widget)

**Start simple, add layers when complexity demands it.** Don't build a cathedral for a shed.

---

## How To Decide Where Code Goes

Ask these questions in order:

```
"Does this code make an HTTP call or read from storage?"
    YES -> Data Layer (DataSource)

"Does this code convert JSON to/from Dart objects?"
    YES -> Data Layer (Model)

"Does this code coordinate between data sources?"
    YES -> Data Layer (Repository Implementation)

"Does this code define what operations are possible (interface)?"
    YES -> Domain Layer (Repository Interface)

"Does this code enforce a business rule?"
    YES -> Domain Layer (Use Case)

"Does this code represent a core concept (wallet, token, transaction)?"
    YES -> Domain Layer (Entity)

"Does this code manage UI state (loading, error, success)?"
    YES -> Presentation Layer (BLoC)

"Does this code build widgets or handle user interaction?"
    YES -> Presentation Layer (Screen/Widget)

"Is this code used by multiple features?"
    YES -> Core Layer
```

---

## The Analogy

Think of it like a **restaurant**:

| Layer | Restaurant | Role |
|-------|-----------|------|
| **Presentation** | Dining room | Customers (UI) order and eat. Waiters (BLoC) take orders and deliver food |
| **Domain** | Menu + Kitchen rules | The menu says what's available (repository interface). Kitchen rules say how dishes are prepared (use cases). Recipes define what a dish IS (entities) |
| **Data** | Kitchen + Pantry | Cooks follow recipes using real ingredients (repository impl). The pantry stores ingredients (local datasource). The delivery truck brings ingredients (remote datasource). Ingredient labels show nutrition info (models) |
| **Core** | Building utilities | Electricity, water, health codes - shared infrastructure everything needs |

**The dining room doesn't know how the kitchen works.**
**The kitchen doesn't care what the dining room looks like.**
**The menu connects them - it defines WHAT's possible without saying HOW.**

That's clean architecture.
