# ADR 0002 — Versioned PBKDF2 envelope for the user passcode

**Status:** accepted
**Date:** 2026-05

## Context

The app gates sensitive flows (wallet unlock, recovery-phrase / private-key reveal, send confirmation) behind a 6-digit numeric passcode. Two questions had to be answered:

1. **How is the passcode stored?** Plaintext is unacceptable. A bare hash (e.g. SHA-256) is also unacceptable — the search space for a 6-digit passcode is only one million entries, trivial to brute-force against a leaked hash dump.
2. **How does the format survive change?** PBKDF2 iteration counts age fast; OWASP recommendations have moved from 10k → 100k → 600k+ over the past decade. Whatever we store today, we'll want to upgrade later without breaking existing users.

Earlier installs of the app stored the passcode as raw plaintext in `FlutterSecureStorage`. Any new design has to fold those users in without forcing them to re-create their wallet.

## Decision

Store the passcode using PBKDF2-HMAC-SHA256 with a per-passcode random salt, wrapped in a versioned envelope:

```
v1:<base64 salt>:<iterations>:<base64 hash>
```

- **PBKDF2-HMAC-SHA256** because the `crypto` package already provides HMAC primitives; no extra native dependency.
- **100,000 iterations** as the v1 baseline. This is below the 2025 OWASP recommendation (~600,000) but the v1 envelope is explicitly designed so we can ship a `v2` with a higher count without invalidating existing hashes. See "Consequences" below.
- **16-byte salt**, freshly generated per `hash()` call, so two identical passcodes produce different stored values.
- **32-byte derived hash**, compared in constant time on verify.
- **`v1:` prefix** is the version envelope. `verify()` reads the prefix, splits the rest, and routes accordingly.
- **Legacy plaintext fallback.** Any stored value that doesn't start with `v1:` is treated as a legacy plaintext passcode. `verify()` does a constant-time string compare. On a successful verify, `PasscodeBloc._onVerifyPasscode` silently re-hashes the passcode and overwrites the storage entry, migrating the install opaquely.

Both `hash()` and `verify()` run on a background isolate via `compute()` — PBKDF2 at 100k iterations takes ~150ms on a low-end Android, easily long enough to drop frames if it ran on the UI isolate. Legacy plaintext compare stays on the main isolate because it's effectively free.

## Consequences

**Positive**

- A leaked storage dump no longer trivially yields the passcode. An attacker has to run PBKDF2-100k for each of the 10⁶ candidate 6-digit passcodes against each user's unique salt — still cheap per user, but at least it's no longer instant.
- The version envelope means iteration count, hash algorithm, or even the entire scheme can change later (`v2`, `v3`) with no migration ceremony — `verify()` just reads the prefix and dispatches.
- Legacy plaintext installs are migrated silently on the next successful unlock. No forced re-entry, no UI disruption.
- Constant-time compare on both paths prevents a timing oracle on the verify check.

**Negative**

- 100k iterations is conservative by 2025 standards. The right number is closer to 600k. This is a known follow-up (`v2` envelope) and the version mechanism is the reason we can ship it later without a breaking migration.
- Even with PBKDF2, a 6-digit passcode has only ~20 bits of entropy. PBKDF2 raises the per-guess cost but it does not change the search space. Real security still depends on `FlutterSecureStorage` keeping the hash blob off-device-attacker reach, the device passcode, and the rate-limit / lockout logic in `PasscodeBloc` (5 attempts, then lockout).
- `compute()` adds a small isolate-spawn cost per call. Acceptable for a passcode flow that happens once per unlock; not acceptable if PBKDF2 ever moves into a tight loop (it doesn't, and shouldn't).

## Alternatives considered

**A. Plaintext in `FlutterSecureStorage`.** The original implementation. Rejected as a permanent solution because keychain extraction tools exist, jailbreak tools exist, and a 6-digit string in plaintext gives an attacker the answer in the same step they get the hash.

**B. Argon2.** Stronger against GPU attack than PBKDF2. Rejected for v1 because it would require adding a native dependency (no maintained pure-Dart Argon2 implementation at acceptable performance). The version envelope leaves the door open for a v2 Argon2 envelope later.

**C. Encrypt the mnemonic with a passcode-derived key (no separate hash).** Considered. The advantage: there's no "verify" step that could be bypassed — you either decrypt to a valid mnemonic or you don't. Rejected for v1 because the existing code path stores the mnemonic separately in `WalletAccountsStore` and re-architecting that to a passcode-encrypted blob is a larger change than this envelope can justify. A future v2 could combine the two: derive a key, encrypt the mnemonic-store blob, drop the standalone hash.

## See also

- `lib/core/security/passcode_crypto.dart` — implementation.
- `test/core/security/passcode_crypto_test.dart` — round-trip, legacy path, malformed-input, v1-envelope assertions.
- `lib/features/wallet/presentation/bloc/passcode_bloc.dart` — call site that does the silent legacy → v1 migration.
- ADR 0001 — centralized Keyring (sibling decision on the signing side).
