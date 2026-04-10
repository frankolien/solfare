# Import Wallet — How It Works

## The Big Picture

Importing a wallet means: **take a recovery phrase someone already has, derive the same keys, and access the same wallet.**

No data is downloaded. No server is contacted. The wallet address is **derived mathematically** from the 12/24 words — the same words always produce the same address, on any device, in any app.

---

## The Flow

```
User types 12 words
    ↓
UI sends ImportWalletEvent(mnemonic)
    ↓
BLoC calls _repository.importWallet(mnemonic)
    ↓
Repository calls _localDataSource.deriveWallet(mnemonic)
    ↓
DataSource validates mnemonic (BIP39 wordlist check)
    ↓
DataSource converts mnemonic → 64-byte seed
    ↓
DataSource derives ED25519 keypair using Solana's derivation path (m/44'/501'/0'/0')
    ↓
DataSource extracts 32-byte public key
    ↓
DataSource encodes public key → Base58 address
    ↓
Returns Wallet(address, publicKey, mnemonic)
    ↓
BLoC emits WalletCreated(wallet, isImported: true)
    ↓
UI listener catches it → dispatches SaveWalletEvent
    ↓
BLoC saves mnemonic + address to flutter_secure_storage
    ↓
BLoC emits WalletSaved
    ↓
UI shows "Wallet imported" result screen
    ↓
User taps "Quick setup" → goes to homepage
    ↓
Homepage loads address from storage → fetches balance from Solana RPC
```

---

## What We Built (Layer by Layer)

### Domain Layer — Already existed

**Entity:** `wallet.dart`
- `Wallet` class with `address`, `publicKey`, `mnemonic`
- No changes needed — same entity for create and import

**Repository Interface:** `wallet_repository.dart`
- `importWallet(String mnemonic)` — was already defined
- The interface just says "this operation exists"

**Use Case:** `import_wallet.dart`
- `ImportWalletUseCase` — was already defined
- Simple pass-through: calls `repository.importWallet(mnemonic)`
- We skipped using it in the BLoC because it's a one-liner — BLoC calls the repository directly

### Data Layer — Already existed

**DataSource:** `wallet_local_datasource.dart`
- `deriveWallet(String mnemonic)` — was already implemented
- This is the SAME method that `createWallet()` calls internally
- `createWallet()` = generate mnemonic + `deriveWallet()`
- `importWallet()` = user provides mnemonic + `deriveWallet()`
- The derivation logic is identical — only the source of the mnemonic changes

**What `deriveWallet` does step by step:**
1. Validates the mnemonic against BIP39 wordlist (`bip39.validateMnemonic`)
2. Converts mnemonic to 64-byte seed (`bip39.mnemonicToSeed`)
3. Derives ED25519 key using Solana's HD path (`ED25519_HD_KEY.derivePath`)
4. Extracts 32-byte public key (`ED25519_HD_KEY.getPublicKey`)
5. Handles edge case: library sometimes returns 33 bytes (strips prefix)
6. Encodes public key to Base58 string = the Solana address (`base58.encode`)
7. Validates the address decodes back to 32 bytes (sanity check)
8. Returns `WalletModel`

**Repository:** `wallet_repository_impl.dart`
- `importWallet()` — was already implemented
- Calls `_localDataSource.deriveWallet(mnemonic)`
- Catches `KeyDerivationException` and wraps it as `WalletCreationFailure`

### Presentation Layer — What we built

**Event:** `wallet_event.dart`
```
ImportWalletEvent
  - field: String mnemonic (the 12/24 words the user typed)
  - props: [mnemonic] (for Equatable comparison)
```

Why does it have a field? Because the BLoC needs to know WHAT mnemonic to import. Unlike `CreateWalletEvent` (which generates its own), the import needs the user's input.

**State:** Reused `WalletCreated`
```
WalletCreated(wallet, isImported)
  - isImported: true for import, false for create
```

We added `isImported` to `WalletCreated` instead of making a separate `WalletImported` state. Why? Because the UI response is nearly identical — the same wallet data comes back. The `isImported` flag lets the listener distinguish between the two when needed.

**BLoC Handler:** `_onImportWallet`
```
1. Emit WalletLoading
2. Call _repository.importWallet(event.mnemonic)
3. If success → emit WalletCreated(wallet, true)
4. If error → emit WalletError(message)
```

Same pattern as every other handler. Emit loading, try the operation, emit success or error.

**Screen:** `import_wallet_screen.dart`

Three stages in one screen using `_ImportStage` enum:

**Stage 1 — Input:**
- Single TextField for pasting/typing the recovery phrase
- Paste button below a divider
- Confirm button at bottom (yellow when text is entered, grey when empty)
- Validates word count (must be 12 or 24)

**Stage 2 — Analyzing:**
- Shield loader lottie animation (`shield_loader.json`)
- "Checking your wallets for existing assets" text
- Appears while BLoC processes the mnemonic
- Transitions to result when `WalletSaved` state is received

**Stage 3 — Result:**
- Shows "Wallet imported" or "No active wallets found"
- "Quick setup" button (yellow) → goes to homepage
- "Advanced" button (grey) → future feature

`AnimatedSwitcher` handles smooth transitions between stages.

**Route:** `app_router.dart`
- Added `AppRoutes.importWallet = '/import-wallet'`
- Slide-in transition from right (matches other routes)

**Onboarding:** `onboarding_screen.dart`
- Wired "I already have a Wallet" button → `context.push(AppRoutes.importWallet)`

---

## The Listener Flow (Most Important Part)

```
Stage: INPUT
    User taps Confirm
    → stage changes to ANALYZING
    → ImportWalletEvent dispatched

Stage: ANALYZING
    BLoC emits WalletLoading → listener logs "Loading..."
    BLoC emits WalletCreated → listener dispatches SaveWalletEvent
    BLoC emits WalletLoading → listener logs "Loading..." (save is in progress)
    BLoC emits WalletSaved → listener waits 1.5s then shows result

Stage: RESULT
    All BLoC states ignored (guard: if stage != analyzing, return)
    User taps "Quick setup" → context.go(homepage)
```

**Key detail:** The guard `if (_stage != _ImportStage.analyzing) return;` prevents other BLoC events (like homepage loading balance) from interfering with the import flow.

**Key detail:** We wait for `WalletSaved` (not `WalletCreated`) before showing the result. This ensures the wallet is actually stored in secure storage before we declare success.

---

## Why Import and Create Share Code

```
createWallet():
    1. Generate mnemonic (BIP39)     ← only difference
    2. Derive keypair from mnemonic
    3. Return Wallet

importWallet(mnemonic):
    1. Use provided mnemonic         ← only difference
    2. Derive keypair from mnemonic
    3. Return Wallet
```

Steps 2 and 3 are identical — both call `deriveWallet()`. The ONLY difference is where the mnemonic comes from. This is why the data layer was already done before we started — `createWallet` already contained all the derivation logic.

---

## Why "No Active Wallets Found" Can Still Be Correct

The real Solflare checks if the derived wallet holds any assets on-chain. If the wallet is empty (0 SOL, no tokens), it shows "No active wallets found" — the wallet EXISTS (the address is valid), but it has no activity.

This doesn't mean the import failed. It means:
- The mnemonic is valid
- The keys were derived successfully
- The address exists on the blockchain
- But that address has never received any tokens

The user can still proceed with "Quick setup" and start using the wallet (receive SOL, airdrop on devnet, etc.)

---

## What You Learned

1. **Import is just derivation** — no network call needed to "get" the wallet
2. **Same derivation logic** — create and import share the same core code
3. **Multi-stage screens** — one widget, multiple visual states, controlled by an enum
4. **Listener guards** — `if (stage != expected) return` prevents state conflicts
5. **Event ordering matters** — wait for save confirmation before showing success
6. **Reusing states** — added `isImported` flag instead of creating a whole new state class
