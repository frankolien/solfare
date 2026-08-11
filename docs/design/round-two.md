# Five things from the device

Ordered by what they cost, not by what they are worth. Each is committed
separately.

## 1. The wrong passcode says nothing

`PasscodeGate.verify` returns `PasscodeWrong(remaining)`. The bloc matches
`case PasscodeWrong():` without binding it, so the count is computed and
dropped. The keypad clears with a buzz and a red dot, which is
indistinguishable from a mis-tap, and the user learns they are locked out only
when they are.

Bind it. `PasscodeError` already draws a red snackbar on that screen, so the
wording is the only new thing: "Wrong passcode. 2 tries left." Singular at one.
The lockout message already exists in `PasscodeGate.describe`.

## 2. Enabling Face ID prompts for nothing

Writing a keychain item under `biometryCurrentSet` needs no authentication —
only *reading* it does. So the toggle writes silently and the user gets no
prompt, no confirmation, no sign it worked.

Enable becomes write-then-read-back: the read raises the OS prompt, so the user
confirms with their face, and it proves the round trip works before we claim
the feature is on. A write we never read is a promise we have not checked —
and the failure would surface at the next unlock, which is the worst place to
find out.

## 3. Change passcode does nothing

`onTap: () {}`. The flow has to be: verify the current passcode through
`PasscodeGate` (so it is rate-limited like every other check), take a new one
twice, then `PasscodeCrypto.create` → write the digest → **rewrap every
mnemonic with the new wrapKey** → `BiometricLock.rekey`.

The rewrap is the part that must not be skipped. The stored mnemonics are
sealed with the old `wrapKey`; writing a new digest without re-sealing them
strands every wallet behind a key nothing can derive again. Order matters for
the same reason it did in the envelope migration: unwrap with the old key while
it is still held, then write the new digest, then wrap with the new key.

## 4. Import a private key

The store holds `WalletAccount.mnemonic`, a `String`, and `Keyring` derives
everything from a BIP-39 phrase. A private key has no phrase, so this is a
storage question before it is a screen question.

Two shapes are worth accepting, because they are what other wallets export:

- base58, 64 bytes (secret + public, the Phantom/Solflare export)
- a JSON array of 64 integers (the `solana-keygen` file)

Stored with a prefix in the same field — `pk:<base58>` — rather than a new
column. The field already carries a `v2:` envelope prefix, so a discriminated
string is the shape it is in; a schema change would mean migrating every
existing entry to gain nothing.

The consequence to handle honestly: **a private-key wallet has no recovery
phrase**, and the export screen must say so rather than showing an error or an
empty box.

## 5. Currency

The setting exists and does nothing. Prices arrive in USD from two places:
CoinGecko for SOL, Helius DAS `token_info.price_info` for SPL tokens.

CoinGecko takes `vs_currencies`, so ask it for both at once:

    /simple/price?ids=solana&vs_currencies=usd,ngn

The ratio of those two is the rate, and it converts every USD figure in the
app, including the ones Helius supplies. One request through the existing
`CoinGeckoClient`, which already caches and throttles, and no new dependency.

Rate, not per-source conversion: asking each price source for a different
currency would mean two sources disagreeing about the rate on the same screen.

Cached with the price, because a wallet that cannot reach CoinGecko must still
render money. A stale rate is wrong by a fraction of a percent; a missing one
means every figure on the screen is blank.
