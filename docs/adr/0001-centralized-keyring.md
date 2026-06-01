# ADR 0001 — Centralize mnemonic → keypair derivation in a single `Keyring`

**Status:** accepted
**Date:** 2026-05

## Context

Five separate call sites in the codebase were independently deriving a Solana keypair from the stored mnemonic:

- `WalletLocalDataSourceImpl.deriveWallet` — wallet create / import.
- `WalletBloc._onSendSol` — sending SOL.
- `StakingBloc._onDelegateStake` and `StakingBloc._deriveKeyPair` — stake / deactivate / withdraw.
- `SwapBloc._onExecuteSwap` — Jupiter swap signing.
- `ExportPrivateKeyScreen._loadKey` — private key reveal.

Each one re-implemented the same three steps: `bip39.mnemonicToSeed` → `ED25519_HD_KEY.derivePath(SolanaPath.defaultPath, seed)` → `Ed25519HDKeyPair.fromPrivateKeyBytes`. One site (`SwapBloc`) used a hardcoded `"m/44'/501'/0'/0'"` string literal instead of the `SolanaPath.defaultPath` constant — exactly the kind of drift that turns into a bug.

For a self-custody wallet, key derivation is a single audited primitive. Spreading it across five files means:

- Any future change (path tweak, parameter change, library upgrade) has to be made in five places, perfectly.
- Defensive measures like buffer scrubbing are easy to add in one place and impossible to retrofit consistently across five.
- The 32-vs-33-byte ed25519 public-key quirk in the underlying library (where `ED25519_HD_KEY.getPublicKey` prepends a 0x00 by default) has to be remembered everywhere.

## Decision

Introduce `lib/core/wallet/keyring.dart` exposing three static methods:

- `keyPairFromMnemonic(mnemonic) → Future<Ed25519HDKeyPair>` — signing path.
- `privateKeyBytes(mnemonic) → Future<Uint8List>` — caller-owned bytes for the export-key screen (which scrubs them on dispose).
- `publicKeyFor(mnemonic) → Future<({Uint8List publicKey, String address})>` — wallet creation path that doesn't need a full keypair.

All five call sites now route through `Keyring`. The 32-vs-33-byte strip, the BIP-44 path, and the `try/finally` zeroing of intermediate seed + private-key buffers all live in one place.

## Consequences

**Positive**

- One audited derivation primitive. The next change (e.g. multi-account support at the BIP-44 `change` index) is a one-line edit.
- Buffer scrubbing is uniform. Before this refactor, only `WalletBloc._onSendSol` had a `_zeroBytes` helper; the other four sites left intermediate keys to the GC.
- `SwapBloc` no longer has a hardcoded path string. If the project ever supports a non-default derivation path, there's exactly one constant to change.
- The 32-vs-33-byte ed25519 quirk is documented and handled once. Callers never have to know.

**Negative**

- One more file in `lib/core/wallet/`. A new contributor has to know `Keyring` exists before they reach for `bip39` directly. The class docstring and the consolidation itself make this easy to discover.
- Tests now mock `Keyring` instead of the lower-level `ED25519_HD_KEY`. Acceptable — `Keyring` is what callers actually depend on.

## Alternatives considered

**A. Leave the duplication.** Five copies of the same six-line block. Rejected — the drift to a hardcoded path string in `SwapBloc` proved the cost is already being paid.

**B. Put the derivation in `WalletLocalDataSourceImpl` and force everything through the repository.** Considered, but the staking and swap flows don't have full repository plumbing — and forcing them to take a `WalletRepository` dependency just to call one method would deepen the cross-feature coupling that already exists between `StakingBloc` and `WalletRepositoryImpl`. A flat `Keyring.staticMethod` is the lighter dependency.

**C. Extract a `KeyringService` with DI / constructor injection.** Over-engineered for a stateless primitive. The three public methods are pure functions of the mnemonic — there's nothing to inject or mock that a static class can't express.

## See also

- `lib/core/wallet/keyring.dart` — the primitive.
- `test/core/wallet/keyring_test.dart` — determinism + invariant tests.
- ADR 0002 — versioned passcode envelope (sibling decision on the security side).
