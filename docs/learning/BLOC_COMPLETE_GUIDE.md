# BLoC Pattern - Complete Guide (From Zero)

> BLoC = Business Logic Component
> It's a pattern for managing state in Flutter. That's it. No magic.

---

## The Core Idea

```
User does something (EVENT)
    -> BLoC receives it
    -> BLoC does some work (logic, API calls, etc.)
    -> BLoC outputs a new STATE
    -> UI rebuilds based on the new state
```

Think of BLoC like a **machine**:
- You put something IN (event)
- Something comes OUT (state)
- The UI just watches what comes out and reacts

---


## The Three Pieces

Every BLoC feature has exactly three files:

### 1. Events (the INPUT)

Events represent **things that happen**. User tapped a button, screen loaded, timer fired.

- An event is just a class that says "this happened"
- It can carry data (e.g., "user typed this address", "user wants to send this amount")
- Events are **past tense or imperative**: `CreateWalletEvent`, `RequestAirdropEvent`, `FetchBalanceEvent`
- The BLoC receives events and decides what to do

**How to think about it:**
- Every user action = one event
- Every automatic trigger (screen load, timer) = one event
- If the UI needs to tell the BLoC something, it sends an event

### 2. States (the OUTPUT)

States represent **what the UI should show right now**. Loading spinner, data, error message.

- A state is just a class that describes the current situation
- The UI reads the state and builds accordingly
- States are **adjectives or nouns**: `WalletLoading`, `WalletCreated`, `WalletError`, `BalanceFetched`

**Common state patterns:**
- **Initial** - nothing has happened yet (show default UI)
- **Loading** - something is in progress (show spinner)
- **Success/Loaded** - data is ready (show the data)
- **Error** - something went wrong (show error message)

**How to think about it:**
- For every possible screen condition, there should be a state
- Ask yourself: "What are all the things this screen could look like?" Each answer is a state

### 3. BLoC (the MACHINE)

The BLoC itself is where the logic lives. It:
- Listens for events
- Runs logic (call an API, read from storage, calculate something)
- Emits new states

**How to think about it:**
- For each event, write a handler function
- The handler does the work and emits states along the way
- Typically: emit Loading -> do work -> emit Success or Error

---

## How Data Flows (Step by Step)

```
1. User taps "Create Wallet" button

2. UI code says:
   context.read<WalletBloc>().add(CreateWalletEvent())
   (This sends the event INTO the BLoC)

3. BLoC receives CreateWalletEvent
   -> Handler function runs
   -> Emits WalletLoading state (UI shows spinner)
   -> Calls repository to create wallet
   -> If success: emits WalletCreated state (UI shows success)
   -> If error: emits WalletError state (UI shows error)

4. UI is listening with BlocBuilder or BlocListener
   -> Sees new state
   -> Rebuilds accordingly
```

---

## BlocBuilder vs BlocListener vs BlocConsumer

These are how the UI **reacts** to state changes. Each has a specific purpose.

### BlocBuilder
- **Rebuilds UI** when state changes
- Use for: showing data, showing loading spinners, showing error messages
- It RETURNS a widget

**When to use:**
- Displaying a balance amount
- Showing/hiding a loading spinner
- Rendering a list of transactions
- Any visual change on screen

### BlocListener
- **Runs side effects** when state changes (does NOT rebuild UI)
- Use for: showing snackbars, navigating to another screen, showing dialogs
- It does NOT return a widget - it just runs code

**When to use:**
- Navigate to next screen after wallet is created
- Show a toast message "Airdrop successful!"
- Show an error dialog
- Any one-time action that isn't a visual rebuild

### BlocConsumer
- **Both** BlocBuilder + BlocListener combined
- Use when you need to both rebuild UI AND run side effects from the same state change

**When to use:**
- Update the balance display AND show a success toast
- Rebuild a form AND navigate away

### The Rule:
- If you need to **show something** -> BlocBuilder
- If you need to **do something** (navigate, toast, dialog) -> BlocListener
- If you need **both** -> BlocConsumer

---

## BlocProvider

Before you can use a BLoC, you need to **provide** it to the widget tree.

- BlocProvider creates the BLoC instance and makes it available to all child widgets
- Usually placed high in the widget tree (at the route level or app level)
- Child widgets access it with `context.read<MyBloc>()` (to send events) or `context.watch<MyBloc>()` (to react to state)

**MultiBlocProvider** - when you need to provide multiple BLoCs at the same level

**Where to put providers:**
- If the BLoC is used across the whole app -> at the app/router level
- If the BLoC is used on one screen -> at that screen's route level
- If the BLoC is used in one widget -> wrap just that widget

---

## Equatable (Why It Matters)

BLoC uses **equality checks** to decide if a state has actually changed.

By default, two objects in Dart are only equal if they're the exact same instance. So even if two `BalanceFetched(balance: 5.0)` objects have the same data, Dart thinks they're different.

**Equatable** fixes this:
- Makes two objects equal if their properties are the same
- This prevents unnecessary UI rebuilds (if the state data hasn't actually changed, don't rebuild)
- Your events and states should extend Equatable and list their properties

---

## Multiple BLoCs

An app usually has **multiple BLoCs**, one per feature/concern:

- **WalletBloc** - wallet creation, balance, transactions
- **PasscodeBloc** - passcode setup and verification
- **SwapBloc** - token swapping (future)
- **StakeBloc** - staking operations (future)

**Rules:**
- Each BLoC has ONE responsibility
- BLoCs should NOT directly talk to each other
- If one BLoC needs to react to another's state, the UI listens to both and coordinates
- Keep BLoCs focused and small rather than one giant BLoC

---

## The BLoC's Relationship to Clean Architecture

```
UI (Screen/Widget)
    |
    | sends events to / listens to states from
    |
    v
BLoC (Presentation Layer)
    |
    | calls methods on
    |
    v
Repository / Use Case (Domain Layer)
    |
    | implemented by
    |
    v
Data Source (Data Layer)
    |
    | talks to
    |
    v
External World (API, Database, Secure Storage)
```

**The BLoC sits in the Presentation Layer** because:
- It manages UI state
- It receives UI events
- It emits UI states

**The BLoC does NOT:**
- Make HTTP calls directly (that's the data source's job)
- Know about databases or storage (that's the data layer's job)
- Contain business rules (that's the domain layer's job, though simple apps skip this)

**The BLoC DOES:**
- Orchestrate: receive event -> call the right use case/repository -> emit state
- Handle loading/error/success flow
- Transform data from domain format to UI format if needed

---

## Event Transformations and Advanced Patterns

### Debouncing
- When the user types in a search box, you don't want to call the API on every keystroke
- Debounce: wait until the user stops typing for 300ms, then fire
- Done with `transformer` parameter on event handler

### Concurrent vs Sequential Events
- By default, events are processed one at a time in order
- You can change this if you need events to process concurrently
- Example: fetching balance and transaction history at the same time

### Event-to-Event
- Sometimes one event completing should trigger another
- Example: after `WalletCreated`, automatically trigger `FetchBalanceEvent`
- The BLoC can `add()` events to itself inside a handler

---

## Common Mistakes

### 1. Putting too much logic in the UI
- BAD: UI fetches data, transforms it, decides what to show
- GOOD: UI sends event, BLoC does the work, UI just renders the state

### 2. One massive BLoC
- BAD: `AppBloc` that handles wallet, auth, settings, tokens, everything
- GOOD: Separate BLoCs per feature

### 3. Not handling all states in the UI
- BAD: Only handling success state, crashing on loading or error
- GOOD: Handle Initial, Loading, Success, AND Error

### 4. Emitting states after the BLoC is closed
- When a screen is popped, the BLoC might be closed
- If an async operation completes after that, emitting will throw
- Check `isClosed` before emitting in long-running operations, or use proper cancellation

### 5. Using context.watch in callbacks
- `context.watch` is for BUILD methods (reactive rebuilds)
- `context.read` is for EVENT HANDLERS (one-time access)
- Using watch in a callback will crash

---

## Mental Model

Think of a BLoC like a **waiter at a restaurant**:

1. **Customer (UI)** places an **order (Event)**: "I want the balance"
2. **Waiter (BLoC)** takes the order to the **kitchen (Repository/DataSource)**
3. Waiter tells customer: "Your order is being prepared" **(Loading state)**
4. Kitchen prepares the food (fetches data, does logic)
5. Waiter brings the food back: "Here's your balance: 5.2 SOL" **(Success state)**
6. OR kitchen says there's a problem: "Sorry, kitchen is down" **(Error state)**

The customer (UI) never goes into the kitchen.
The kitchen never talks directly to the customer.
The waiter (BLoC) is the middleman.

---

## In Your Project Right Now

```
WalletBloc
├── Events: CreateWalletEvent, RequestAirdropEvent, FetchBalanceEvent, etc.
├── States: WalletInitial, WalletLoading, WalletCreated, BalanceFetched, WalletError, etc.
└── Handlers: _onCreateWallet, _onRequestAirdrop, _onFetchBalance, etc.

PasscodeBloc
├── Events: SetPasscodeEvent, VerifyPasscodeEvent, etc.
├── States: PasscodeInitial, PasscodeSet, PasscodeVerified, PasscodeError, etc.
└── Handlers: _onSetPasscode, _onVerifyPasscode, etc.
```

As you add features, you'll add more BLoCs:
- **TokenBloc** - for SPL token operations
- **SwapBloc** - for DEX swaps
- **StakeBloc** - for staking
- Each with their own events, states, and handlers
