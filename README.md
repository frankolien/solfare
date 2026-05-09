# Solfare — Solana Wallet (Flutter)

A non-custodial Solana wallet built with Flutter. It supports the full lifecycle of a self-custody wallet — generating and importing seed phrases, signing transactions on-device, sending and receiving SOL, browsing tokens and NFTs, swapping, staking, and exploring dApps through an in-app browser. Inspired by the Solflare app.

This is a personal project I built end-to-end to deepen my skills in mobile architecture, applied cryptography, and on-chain integration.

## What it does

- **Wallet onboarding** — generate a new wallet (BIP39 mnemonic) or import an existing one, with confirm-phrase verification and biometric / passcode setup.
- **Multi-account support** — create, rename, switch, and export multiple wallets from a single device.
- **Send & receive SOL** — address validation, QR scanning, transaction signing, and live balance updates over WebSocket.
- **Token & NFT views** — fetch SPL tokens and NFTs for the active wallet, with detail screens.
- **Swap** — token swap UI wired to a Solana DEX aggregator.
- **Staking** — stake SOL to a validator and view stake account details.
- **Market data** — token prices, charts (fl_chart), and watchlist powered by CoinGecko.
- **Explore / dApp browser** — in-app WebView for interacting with Solana dApps.
- **Address book**, multi-language support (l10n), light/dark theming, configurable RPC network (Mainnet / Devnet).

## Security

- Mnemonics and private keys are stored in the OS keystore via `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on Android).
- The app is locked behind a user-set passcode; the passcode is never stored in plaintext — it derives a key used to encrypt sensitive material (`lib/core/security/passcode_crypto.dart`).
- Biometric unlock (Face ID / fingerprint) gates sensitive flows.
- `flutter_windowmanager` blocks screenshots and prevents the app from appearing in the recent-apps preview when sensitive screens are open.
- A secure clipboard helper auto-clears copied secrets after a short timeout.
- Key derivation follows the Solana derivation path (`m/44'/501'/x'/0'`) using `ed25519_hd_key`.

## Architecture

Clean Architecture, organized by feature:

```
lib/
├── core/              # cross-cutting: router, theme, security, network, wallet session
├── features/
│   ├── wallet/        # data / domain / presentation
│   ├── swap/
│   ├── staking/
│   ├── market/
│   ├── explore/
│   ├── homepage/
│   └── settings/
├── shared/            # splash, onboarding, reusable widgets
└── l10n/              # localization
```

Each feature is split into:
- **data** — datasources (Solana RPC, CoinGecko, secure local store) and repository implementations
- **domain** — entities, repository interfaces, use-cases
- **presentation** — Bloc/Cubit, screens, widgets

## Tech stack

- **Flutter / Dart** (SDK ^3.9.2)
- **State management:** flutter_bloc
- **Routing:** go_router
- **Solana:** `solana` package (RPC + transaction signing), `bip39`, `ed25519_hd_key`, `bs58`
- **Secure storage:** `flutter_secure_storage`, `flutter_windowmanager`
- **Networking:** `http`, `web_socket_channel` (live balance updates)
- **UI:** `fl_chart`, `lottie`, `flutter_svg`, `qr_flutter`, `qr_code_dart_scan`, custom FKGrotesk typography
- **Web / dApps:** `webview_flutter`
- **Misc:** `share_plus`, `url_launcher`, `image_picker`, `shared_preferences`, `flutter_dotenv`

## Running locally

```bash
flutter pub get
cp .env.example .env   # add your RPC endpoint and any API keys
flutter run
```

The app defaults to Solana Mainnet; Devnet can be selected from Settings → Network.

## Status

Active personal project. Core wallet flows (create, import, send, receive, balances, history, staking, swap UI, market, dApp browser) are implemented. Continuing to harden security flows, polish UI, and expand SPL token coverage.

## Build journey

I documented this build on X — short demos and progress clips:

- [Demo 1](https://x.com/frank_olien123/status/2043789527555154108)
- [Demo 2](https://x.com/frank_olien123/status/2042661682837668019)
- [Demo 3](https://x.com/frank_olien123/status/2040119660851368031)

Follow along: [@frank_olien123](https://x.com/frank_olien123)

## About me

I'm a Flutter developer focused on mobile apps that touch crypto, security, and real-time data. If you're hiring, reach out — Frankolien123@gmail.com.
