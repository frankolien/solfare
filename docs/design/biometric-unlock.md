# Biometric unlock

Face ID instead of typing six digits every time.

## The problem this has to solve first

`BiometricSetupScreen` currently says "Biometric unlock is coming soon" and
routes on. `local_auth` is not a dependency. Four languages already carry
`enableBiometrics` and `unlockBiometricDesc`; nothing reads them.

But the real obstacle is not the missing plugin. It is that unlocking is no
longer a navigation decision.

Since the passcode envelope, the recovery phrase is sealed with `wrapKey`,
derived from the passcode by PBKDF2 → HKDF and **never stored**. Typing the
passcode is what re-derives it. So a Face ID that merely says "yes, it's them"
opens the router and leaves the app unable to read its own seed — every send,
swap and stake would fail on a wallet that looks unlocked.

Biometrics therefore has to produce the *key*, not a verdict.

## The wrong way, which is the common way

```dart
if (await LocalAuthentication().authenticate(...)) {
  AppLock.instance.unlock();          // and wrapKey comes from where?
}
```

Two problems. The key question is unanswered, and the gate is a boolean
returned by a plugin — on a jailbroken device that boolean is one hook away
from always being true. The keychain is untouched, so anything that can read
storage still holds everything it held before.

## The design

Store `wrapKey` under an access control the OS enforces at read time.

    SecureStore.write(
      key: 'wallet_biometric_key',
      value: base64(wrapKey),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.passcode,
        accessControlFlags: [AccessControlFlag.biometryCurrentSet],
      ),
    )

There is no boolean to defeat. The bytes do not leave the keychain unless the
Secure Enclave authenticates the face in front of the phone. A keychain dump
returns nothing for this item.

`biometryCurrentSet` rather than `biometryAny` on purpose: the item is
destroyed the moment a new face or finger is enrolled. If somebody adds
themselves to a phone they have borrowed, the key dies rather than becoming
theirs — and the passcode still works, so the cost of that is one prompt.

Accessibility `passcode` — the plugin's name for
`WhenPasscodeSetThisDeviceOnly` — because an item with no device passcode
behind it has nothing to protect it, and because it must never sync anywhere.

## What `local_auth` is still for

Capability detection and naming only — whether the device has biometrics
enrolled, and whether to write "Face ID" or "Touch ID" on the button. It is
never the gate. Writing the toggle without it would mean offering Face ID on a
device that has none and explaining the failure afterwards.

## Flow

**Enabling** — only reachable while unlocked, which means `WalletKey` is held:

1. Ask `local_auth` whether biometrics exist and are enrolled. If not, the
   toggle is not offered at all.
2. Write `wrapKey` under the access control above.
3. Write `biometric_enabled = true` as an ordinary item, so the unlock screen
   can know whether to offer the button *without* triggering a prompt to find
   out.

**Unlocking:**

1. Router redirects a locked app to the unlock screen, as today.
2. If `biometric_enabled`, prompt once on mount, and leave a button for retry.
3. Read `wallet_biometric_key`. iOS prompts. On success the value *is* the real
   `wrapKey` — `WalletKey.hold`, `AppLock.unlock`, and run
   `wrapPlaintextMnemonics` exactly as `PasscodeGate` does, so a half-finished
   migration still completes on a biometric unlock.
4. On cancel, failure, or a `PlatformException` from an invalidated item: the
   keypad is already on screen. Nothing else happens.

**Disabling** — delete both items.

## Invalidation, which is where this goes wrong

| event | required action |
|---|---|
| passcode changed | `wrapKey` changed; rewrite the item or the old key unwraps nothing |
| wallet wiped / `AppLock.forget()` | delete both items |
| new face or finger enrolled | OS invalidates it; the read throws, clear the flag, fall back |
| biometrics turned off in Settings | same as above |

The passcode change case is the dangerous one. Forgetting it leaves a stored
key that decrypts nothing, and the failure surfaces as "your recovery phrase
could not be read" — which reads like data loss. It is handled where the digest
is written, not where the toggle lives.

## What this does not do

It does not make the wallet harder to break into offline. The v2 digest is
still on disk and a six-digit passcode is still ~20 bits; an attacker with the
storage blob attacks that, not this. Biometrics removes a per-unlock cost for
the user and nothing else. Claiming otherwise in the UI would be a lie.

## Tests

- enabling with no biometrics enrolled does not write the item
- a stored key round-trips to the same `wrapKey` the passcode derives
- an unlock via the biometric path unwraps a mnemonic wrapped by the passcode path
- a read that throws leaves `WalletKey` empty and the app locked
- changing the passcode rewrites the item; the old value no longer unwraps
- wiping the wallet deletes both items
