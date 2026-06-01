# Solfare — Solana Wallet (Flutter)

A self-built clone of the Solflare wallet, written from scratch in Flutter. Built solo as a deep-dive into wallet security, Solana RPC, and the mobile patterns a self-custody app has to get right.

**Where it's strong:** the security core. Centralized [`Keyring`](lib/core/wallet/keyring.dart) primitive for every signing call site, versioned PBKDF2 envelope for passcode storage with silent legacy-plaintext migration ([ADR 0002](docs/adr/0002-versioned-pbkdf2-passcode-envelope.md)), `FlutterSecureStorage` explicitly configured with `KeychainAccessibility.first_unlock_this_device`, intermediate-buffer scrubbing after key derivation, post-send polling fallback for flaky WebSockets, in-flight wallet-switch guards so stale balance responses can't pollute the new account's UI, lifecycle-aware WebSocket with exponential backoff, an iOS-side `MethodChannel` that paints a privacy overlay on the app-switcher snapshot, and 29 unit tests for the security primitives.

**Where it's not:** this is a Flutter-only project. There is no advanced native iOS or Android code beyond the screenshot-blocking `MethodChannel` — no Secure Enclave integration, no hardware wallet support, no SSL pinning, no deep-link / Universal Link / MWA wiring. Android release still signs with debug keys. PBKDF2 iteration count is 100k, below the 2025 OWASP recommendation of ~600k (the version envelope is set up for an upgrade). And as a solo project, it has no shipped-to-production scar tissue — only what I learned reverse-engineering Solflare.

If you're hiring for a wallet team and the bar is "production native iOS expertise," this repo can't carry that case alone. If the bar is "Flutter engineer who understands what a self-custody wallet has to get right, and who treats AI output as a draft," this repo is exactly that.

## What it does

- **Wallet onboarding** — BIP-39 mnemonic generation or import, with confirm-phrase verification and biometric / passcode setup.
- **Multi-wallet** — create, rename, switch, and export multiple wallets. Lazy migration from the pre-multi-wallet single-mnemonic storage format.
- **Send & receive SOL** — address validation, QR scanning, on-device signing, live balance updates over WebSocket, polling fallback if the WS drops.
- **SPL tokens & NFTs** — Helius DAS for both, with local caching that survives cold restart.
- **Swap** — Jupiter v2 (`/order` + `/execute`) with v0-VersionedTransaction signing on-device.
- **Staking** — single bundled `createAccount + initialize + delegate` transaction so a partial land doesn't leave orphan stake accounts.
- **Market data** — CoinGecko-backed prices and charts via a singleton client with serialised queue, in-flight coalescing, and stale-cache fallback on 429.
- **In-app dApp browser**, address book, l10n, light/dark themes, configurable RPC (Mainnet / Devnet).

## Security model

| Surface | How it's handled |
|---|---|
| Mnemonics + private keys at rest | `FlutterSecureStorage` (iOS Keychain / Android Keystore) with `KeychainAccessibility.first_unlock_this_device` |
| Passcode storage | Versioned envelope `v1:salt:iter:hash` over PBKDF2-HMAC-SHA256; constant-time compare; silent legacy-plaintext migration — see [ADR 0002](docs/adr/0002-versioned-pbkdf2-passcode-envelope.md) |
| Key derivation | Single `Keyring` primitive — every signing path goes through one place — see [ADR 0001](docs/adr/0001-centralized-keyring.md) |
| Intermediate seed + privkey bytes | `try/finally` zeroing inside `Keyring`; `ExportPrivateKeyScreen` scrubs displayed key bytes on dispose |
| Screenshot / app-switcher leak | Android `FLAG_SECURE`; iOS routes through a `MethodChannel` to a Swift handler that paints a privacy overlay on `willResignActive` |
| Clipboard | `SecureClipboard.copySensitive` auto-clears after 30s only if the value hasn't changed |
| Brute-force | 5-attempt lockout in `PasscodeBloc` with backoff |
| Fresh-install hygiene | `_wipeSecureStorageOnFreshInstall` clears stranded Keychain entries on first run after install |

## Architecture

Feature-sliced Clean Architecture. `wallet` is the canonical example with full `data` / `domain` / `presentation` layering; `swap` and `staking` are flatter because they're thinner features and the layering hadn't earned its keep there yet — that inconsistency is honest, not aspirational.

```
lib/
├── core/
│   ├── network/        # http_retry, coingecko_client
│   ├── security/       # passcode_crypto, secure_store, secure_screen, secure_clipboard
│   ├── wallet/         # keyring (single signing primitive), active_wallet
│   └── ...
├── features/
│   ├── wallet/         # data / domain / presentation (full Clean layers)
│   ├── swap/           # data / presentation (flatter)
│   ├── staking/        # presentation only
│   ├── market/ ...
├── shared/             # splash, onboarding, reusable widgets
└── l10n/
ios/Runner/
└── AppDelegate.swift   # MethodChannel for app-switcher privacy overlay
test/
├── core/security/      # passcode_crypto, secure_screen
├── core/wallet/        # keyring (BIP-44 determinism, invariants)
├── core/network/       # http_retry (retry-then-succeed, timeout, max-attempts)
└── features/wallet/    # wallet_accounts_store (fake FlutterSecureStorage via setMockMethodCallHandler)
docs/
├── adr/                # architecture decision records
└── learning/           # personal build-journal markdowns (gitignored from main tracking)
```

29 unit tests for the security primitives. Storage tests fake `FlutterSecureStorage` via `TestDefaultBinaryMessenger` so they run without a device or emulator. Run with `flutter test`.

## Tech stack

Flutter / Dart, `flutter_bloc`, `go_router`, `solana`, `bip39`, `ed25519_hd_key`, `bs58`, `crypto` (PBKDF2-HMAC-SHA256), `flutter_secure_storage`, `flutter_windowmanager`, `http`, `web_socket_channel`, `webview_flutter`, `fl_chart`, `lottie`, `flutter_svg`, `qr_flutter`, `qr_code_dart_scan`. Custom FKGrotesk typography.

## Running locally

```bash
flutter pub get
cp .env.example .env   # add your RPC endpoint and any API keys
flutter run
```

Mainnet by default; Devnet selectable from Settings → Network.

To run the test suite:

```bash
flutter test
```

## Build journey

I've been documenting this build on X — short demo clips:

- [Demo 1](https://x.com/frank_olien123/status/2043789527555154108)
- [Demo 2](https://x.com/frank_olien123/status/2042661682837668019)
- [Demo 3](https://x.com/frank_olien123/status/2040119660851368031)

Longer-form build journal lives at [github.com/frankolien/solflare-clone-guide](https://github.com/frankolien/solflare-clone-guide).

## About me

Flutter developer focused on mobile apps that touch crypto, security, and real-time data. Open to roles — Frankolien123@gmail.com · [@frank_olien123](https://x.com/frank_olien123).
