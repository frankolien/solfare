# Wrapping the mnemonic with the passcode

## What is wrong now

`PasscodeCrypto.hash` derives 32 bytes with PBKDF2-HMAC-SHA256 at 100,000
iterations and stores them as a comparison digest:

```
v1:<base64 salt>:<iterations>:<base64 hash>
```

Verifying re-derives and compares. That is a correct password check, and it
protects nothing. The mnemonic is a plain `String` field on `WalletAccount`
(`wallet_account.dart:9`), written as JSON into the keychain blob under
`wallets_v1`. So the 100,000 iterations gate a boolean, and anyone who can
read the keychain has the seed without ever meeting the passcode:

- a jailbroken or rooted device
- forensic extraction
- malware running with the app's own entitlements

`SecureStore` already pins `first_unlock_this_device`, so the blob does not
travel in an encrypted backup to another device. That closes one route and
not the others.

## What it can and cannot buy — measured first

Before designing anything, the honest ceiling.

A six-digit passcode is ~20 bits. One million candidates. PBKDF2 at 100k
iterations costs an attacker one derivation per candidate, and the attacker
is not running pure Dart — they are running optimised native code, likely on
a GPU, where PBKDF2-HMAC-SHA256 at this iteration count runs on the order of
10⁵ candidates per second. **One million candidates is therefore seconds to
low minutes of offline work, whatever iteration count is realistic here.**

Measured on this machine (M-series, `compute()` isolate, three runs):

| | 100k iterations |
|---|---|
| `hash` | 347ms / 342ms / 339ms |
| `verify` | 350ms / 368ms / 336ms |

A low-end Android is conservatively 3–6× slower, so 100k is already
1–2 seconds there. The OWASP 2025 figure for PBKDF2-HMAC-SHA256 is ~600k,
which would be ~2s on this Mac and 6–12s on that Android — unusable on a
screen the user meets every time the app re-locks. Pure-Dart PBKDF2 is the
binding constraint, and even winning that argument only multiplies the
attacker's seconds by six.

**So the envelope is worth doing and must not be oversold.** It moves the
bar from *read the blob, get the seed* to *read the blob, spend real
compute, get the seed* — which stops trivial extraction and any malware that
is just scraping storage. It is not equivalent to enclave-backed protection.

The actual answer to an attacker holding the blob is hardware: Secure
Enclave on iOS, StrongBox/TEE on Android, where the rate limit is enforced
by the chip and a six-digit PIN is fine because ten wrong guesses is all you
get. That is native work this project does not have, and the README already
says so. This document is the software-only step, not a substitute for it.

## Design

### Where the boundary sits

Only the `mnemonic` field is wrapped, not the whole `wallets_v1` blob.

The wallet list has to be readable without the passcode: the splash screen
asks whether a wallet exists, the home screen shows the address and balance,
the wallet switcher shows names and card backgrounds. Encrypting the whole
blob would make all of that wait on an unlock, and would turn the
"does a wallet exist" check into something that cannot be answered while
locked — which is exactly the question whose wrong answer sends a user to
onboarding and overwrites their seed.

So: `address`, `name`, `cardBackground`, `id`, `createdAt` stay readable.
`mnemonic` becomes ciphertext.

### Key derivation

The stored verification digest must not *be* the encryption key. If it were,
reading the keychain would hand over the key directly and the whole exercise
would be theatre.

One PBKDF2 pass, then split by domain:

```
master  = PBKDF2-HMAC-SHA256(passcode, salt, iterations, 32)
authKey = HKDF-Expand(master, "solfare:auth:v2", 32)   → stored
wrapKey = HKDF-Expand(master, "solfare:wrap:v2", 32)   → never stored
```

HKDF-Expand is a handful of HMAC calls, so this costs the same as today —
the expensive part is the single PBKDF2 pass, unchanged.

Deriving `wrapKey` with a second full PBKDF2 pass over a different salt
would also be safe and would double the unlock cost for no benefit.
(Splitting a longer PBKDF2 output would be safe too — blocks are computed
independently from the password — but it is a subtlety a reader has to
verify, and HKDF is the construction that says what it means.)

### Envelope format

Stored digest, versioned like the existing one so `isLegacyPlaintext` has a
sibling:

```
v2:<base64 salt>:<iterations>:<base64 authKey>
```

Wrapped mnemonic, in the `mnemonic` field:

```
v2:<base64 nonce>:<base64 ciphertext>
```

XSalsa20-Poly1305 via `pinenacl`'s `SecretBox` — already a direct
dependency, already carrying the dapp session traffic, so no new package and
no second cryptographic construction to review. Authenticated, so a
tampered blob fails to open rather than yielding garbage that gets fed to
BIP-39.

A `mnemonic` with no `v2:` prefix is plaintext, exactly the way
`PasscodeCrypto.isLegacyPlaintext` already reasons about the digest.

### Holding the key

`wrapKey` lives in memory for the unlocked session only:

- derived on a successful `PasscodeGate.verify`
- derived on `SavePasscodeEvent`, which is where a passcode first exists
- **cleared by `AppLock.lock()`** — the lock this session already added is
  what gives "unlocked" a lifetime to hang this on

The alternative — prompting for the passcode on every signature — is
strictly stronger and would put a passcode screen in front of every send,
swap and stake. Given the measurement above, the marginal security is small
next to the UX cost: an attacker who can read live process memory has
already lost you more than the seed.

New holder, `lib/core/security/wallet_key.dart`, so the key has one home and
one lifetime rather than being threaded through blocs.

### Reading a mnemonic

`WalletAccountsStore.loadAll` returns accounts with the field as stored.
Unwrapping happens where the mnemonic is actually used, so nothing decrypts
a seed to render a wallet name:

```
plaintext (no prefix)      → return as-is          (pre-migration install)
v2 prefix + key held       → SecretBox.open
v2 prefix + no key         → throw WalletLockedException
v2 prefix + open fails     → throw CorruptWalletStoreException
```

Four call sites read it today, all of them behind the app lock:
`swap_bloc.dart:263`, `staking_bloc.dart:210`, `wallet_bloc` via
`WalletRepositoryImpl.getStoredMnemonic`, and the two export screens (which
have just taken a passcode anyway).

`WalletLockedException` must surface as "unlock to continue", not as a raw
error — the same discipline as `CorruptWalletStoreException`.

### Migration

This runs over live seeds, so the ordering is the whole design.

**Corrected after building the primitive.** The first version of this
section said "wrap the mnemonics, then write the digest", reasoning that a
crash between the two leaves a state the next unlock repairs. That holds for
a v1 digest and is **wrong for a plaintext one**, and the difference is
where the salt comes from:

| upgrading from | salt | `wrapKey` reproducible? |
|---|---|---|
| `v1:` digest | reused from the stored digest | **yes** — measured |
| plaintext | freshly minted, there is no stored salt | **no** — measured |

So for a plaintext install, wrapping first and dying before the digest write
strands every mnemonic behind a key that no longer exists anywhere. That is
the exact failure this whole document is meant to avoid.

**The rule that is safe for both:**

1. verify — the only proof of the passcode
2. derive `master`, `authKey`, `wrapKey`
3. **write the v2 digest first**, if the stored one is not already v2
4. wrap every mnemonic that is still plaintext, and `saveAll` once
5. hold `wrapKey` for the session

Step 3 before step 4 makes the salt durable, so the key is reproducible from
that point on. A crash between them leaves a v2 digest over plaintext
mnemonics: the next unlock verifies v2, derives the *same* key from the
stored salt, and completes step 4.

For that to actually happen, **step 4 must run on every unlock, not only
when the digest needed upgrading** — the condition is "is any mnemonic still
plaintext", not "was the digest old". Gating on the digest is what would
make a half-finished migration permanent.

The reverse of the old worry is harmless: writing the digest and never
wrapping leaves the store exactly as it is today, which is the state every
install is in right now.

There is no partial-write hazard inside step 4 because `saveAll` is a single
`SecureStore.write` of one JSON blob. If it throws, nothing changed.

**A wallet with no passcode** stays plaintext. There is nothing to derive a
key from, and this is an existing state — the splash screen sends those
users to onboarding today.

**Reset** already deletes the passcode (`clearWallet`), and now also clears
the in-memory key.

### Forgotten passcode

Today a forgotten passcode strands the user on the unlock screen with the
seed still readable off the device. After this, it is genuinely
unrecoverable without the recovery phrase.

That is the correct behaviour and it is a promise the setup screen does not
currently make. The passcode-creation screen needs one line saying so.

## Deliberately not in this change

**Raising the iteration count.** The measurement argues for it and the `v1:`
prefix was built to allow it, but changing the KDF cost and the storage
format in the same migration doubles the risk on a path where failure loses
the seed. It is a one-line change to `_iterations` once v2 is out and
settled, and it wants its own before/after timing on a real low-end device
rather than this Mac.

**Enclave-backed key material.** The real fix, and native work.

## Plan

1. `WalletKey` holder — set, clear, `isHeld`. Cleared from `AppLock.lock()`.
2. `PasscodeCrypto` v2: `deriveKeys` returning `(authKey, wrapKey)`, HKDF
   split, v2 digest format, `verify` accepting v1 and v2.
3. `MnemonicEnvelope` — `wrap(mnemonic, key)` / `unwrap(stored, key)`,
   plaintext passthrough, `isWrapped`.
4. `PasscodeGate.verify` populates `WalletKey` on success and runs the
   migration when it verified against a v1 digest.
5. `SavePasscodeEvent` derives and wraps on first passcode.
6. Read path: unwrap at the four call sites, `WalletLockedException`
   surfaced as a message.
7. Tests: round-trip, wrong key fails closed, tampered ciphertext fails
   closed, plaintext passthrough, migration idempotence, migration
   crash-between-steps, locked read refuses, `authKey` is not `wrapKey`.
