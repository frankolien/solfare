# Design — Wallet platform: preview, pay, connect, tokens

**Status:** proposed (nothing implemented)
**Date:** 2026-08

Four features, one shared spine. This document is the plan; the code is the execution of it.
Diagram: [`solfare-system-design.excalidraw`](./solfare-system-design.excalidraw).

- **F1 — Transaction preview + risk engine.** Show what a transaction does to every balance before it is signed.
- **F2 — Solana Pay.** Scan a QR, pay a merchant.
- **F3 — dApp Connect.** Encrypted deeplink sessions so other apps can ask Solfare to sign.
- **F4 — SPL token send + Token-2022.** The wallet can display tokens and cannot send one.

F1 is the spine. F2, F3 and F4 all produce a transaction that a human has to approve, and they should
all approve it through the same surface. Building F1 first means the other three inherit it.

---

## 1. Research findings

Everything below was verified against the installed packages and live RPC, not assumed.

### 1.1 `simulateTransaction` returns balance deltas directly

The headline finding. Simulating a real mainnet versioned transaction against
`api.mainnet-beta.solana.com` returned:

```
['accounts', 'err', 'fee', 'innerInstructions', 'loadedAccountsDataSize',
 'loadedAddresses', 'logs', 'postBalances', 'postTokenBalances',
 'preBalances', 'preTokenBalances', 'replacementBlockhash', 'returnData',
 'unitsConsumed']
```

`preTokenBalances[0]` came back as:

```json
{"accountIndex": 1, "mint": "So111...112", "owner": "CyiWp8...bkx5",
 "programId": "Tokenkeg...VQ5DA",
 "uiTokenAmount": {"amount": "206564", "decimals": 9, "uiAmount": 0.000206564}}
```

Consequences for F1:

- No need to fetch pre-state with `getMultipleAccounts` and diff account data by hand.
- The shape is **identical** to `getTransaction`'s `meta`, which `SolanaRpcDataSourceImpl`
  already parses in `getTransactionHistory` and `_detectNftTransfer`. The delta parser can be
  shared between history and preview.
- `fee` is returned, so the preview shows the real fee rather than an estimate.
- `innerInstructions: true` exposes CPI, which is where a drainer hides the actual transfer.

Two caveats to design around:

- These fields are Agave-version dependent. A provider that omits them must degrade to
  `accounts:{addresses,encoding}` diffing against `getMultipleAccounts`. Treat pre/post balances
  as the fast path, not the only path.
- When `err != null`, the `accounts` array came back as nulls while `preBalances`/`postBalances`
  were still populated. A failing simulation must still render *something* — "this will fail, here
  is why" is the most valuable preview there is.

### 1.2 `solana` package ships Solana Pay

`package:solana/solana_pay.dart` exports:

- `SolanaPayRequest.parse(url)` / `tryParse` → `recipient`, `amount` (`Decimal`), `splToken`,
  `reference`, `label`, `message`, `memo`.
- `SolanaTransactionRequest.parse(url)` → `link` (validated https), `label`, `message`.
- `solana_client_ext.dart` — builds the transfer instruction, resolves the mint's decimals,
  derives both ATAs, and can locate a landed payment by `reference`.

So F2 does not hand-roll URL parsing or spec compliance. It wires an existing module to the
scanner and the preview sheet.

### 1.3 pinenacl gives us Phantom-compatible crypto, already in the tree

`pinenacl` 0.6.0 is present transitively (via `solana`). `package:pinenacl/x25519.dart` exports:

- `PrivateKey.generate()`, `PrivateKey.fromSeed(seed)`, `.publicKey`
- `Box({myPrivateKey, theirPublicKey})` — Curve25519 + XSalsa20 + Poly1305

That is exactly NaCl `crypto_box`, which is what Phantom's and Solflare's deeplink protocols use.
F3 needs no new dependency and no custom crypto.

### 1.4 SPL and Token-2022 primitives exist

- `findAssociatedTokenAddress({owner, mint})` in `solana/src/helpers.dart`
- `AssociatedTokenAccountProgram` (`ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`)
- `TokenInstruction.transferChecked / approve / setAuthority / closeAccount / burn / mintTo`

The instruction factories serve F4 (building) *and* F1 (decoding for risk). Token-2022
(`TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`) has no helper in the package — extensions come
from `getAccountInfo(mint, jsonParsed)` under `data.parsed.info.extensions`.

### 1.5 MWA is not a target

Mobile Wallet Adapter's association step is built on Android intents plus a local WebSocket.
There is no sanctioned iOS path. F3 is the iOS-shaped answer to the same problem, and it is
Solfare's own scheme until a dapp adopts it — that is a distribution problem, not a code problem,
and it should be stated plainly in any writeup.

---

## 2. Shared foundations

```
lib/core/solana/
  transaction_service.dart      exists — build, price, send, confirm
  priority_fee_oracle.dart      exists
  tx_outcome.dart               exists
  preview/
    tx_preview.dart             NEW  TxPreview, BalanceDelta, RiskFlag models
    preview_engine.dart         NEW  simulate -> deltas
    instruction_decoder.dart    NEW  raw instruction -> DecodedInstruction
    risk_engine.dart            NEW  decoded + deltas -> RiskFlag[]
  token/
    mint_info.dart              NEW  Token-2022 extension model
    token_service.dart          NEW  ATA derivation, transfer building
  session/
    dapp_session.dart           NEW  session record + sealed-box codec
    session_store.dart          NEW  persistence, revocation
    dapp_request_router.dart    NEW  deeplink -> typed request
  pay/
    pay_request_resolver.dart   NEW  Solana Pay URL -> ResolvedPayment
```

Two rules that keep this from sprawling:

1. **One approval surface.** Every path that signs — send, swap, stake, pay, dapp — renders the
   same `TxPreviewSheet` fed by the same `TxPreview`. Not four confirm screens.
2. **`TransactionService` stays the only thing that broadcasts.** F2 and F3 hand it instructions
   or a pre-built payload; nothing else calls `sendTransaction`.

---

## 3. F1 — Transaction preview + risk engine

### 3.1 Data model

```dart
class TxPreview {
  final List<BalanceDelta> deltas;   // sorted: user's own accounts first
  final List<RiskFlag> flags;        // sorted by severity
  final int feeLamports;             // simulation's `fee`
  final int computeUnits;
  final bool willFail;               // err != null
  final String? failureReason;
  final List<DecodedInstruction> instructions;
}

class BalanceDelta {
  final String? mint;                // null = native SOL
  final String owner;
  final int rawDelta;                // signed, in base units
  final int decimals;
  final String? symbol;
  final bool isOwnAccount;           // owner == active wallet
}

enum RiskSeverity { info, caution, danger }

class RiskFlag {
  final RiskSeverity severity;
  final String title;                // "Unlimited spending approval"
  final String detail;
  final int? instructionIndex;
}
```

### 3.2 Preview algorithm

```
preview(instructions, signers, feePayer):
  1. blockhash <- rpc.getLatestBlockhash(confirmed)
  2. tx <- sign(message(computeBudget + instructions), blockhash, signers)
     # signed only so the wire format is valid; sigVerify is off
  3. sim <- rpc.simulateTransaction(tx, {
        sigVerify: false, replaceRecentBlockhash: true,
        innerInstructions: true,
        accounts: { encoding: jsonParsed, addresses: writableAccounts }  # fallback path
     })
  4. if sim.preBalances != null:
        deltas <- diffNative(sim.preBalances, sim.postBalances, accountKeys)
                  ++ diffToken(sim.preTokenBalances, sim.postTokenBalances)
     else:
        deltas <- diffAgainst(getMultipleAccounts(writable), sim.accounts)   # degraded
  5. decoded <- decodeAll(instructions ++ flatten(sim.innerInstructions))
  6. flags   <- risk(decoded, deltas, sim.logs)
  7. if sim.err != null:
        willFail <- true; failureReason <- humanize(sim.err, sim.logs)
        # still return deltas and flags — a failing preview is the useful one
  8. return TxPreview(...)
```

`diffNative` must subtract the fee from the fee payer's delta before display, otherwise every
transaction looks like it costs an extra 5000 lamports of "unexplained" SOL.

### 3.3 Instruction decoding

Decode by program id, then by the first byte(s) of `data`:

| Program | What we decode |
|---|---|
| System (`111…`) | transfer, createAccount, assign, allocate |
| Token / Token-2022 | transfer, transferChecked, approve, approveChecked, revoke, setAuthority, closeAccount, burn, mintTo |
| ATA program | create, createIdempotent |
| Compute budget | limit, price (hidden from display — noise) |
| Stake | delegate, deactivate, withdraw, authorize |
| Memo | UTF-8 payload, shown verbatim |
| anything else | `Unknown program <id>` — a fact, not a guess |

Never invent a friendly name for a program we do not recognise. "Unknown program" is honest;
"Swap" would be a lie a drainer can exploit.

### 3.4 Risk rules

| Rule | Severity | Trigger |
|---|---|---|
| Unlimited approval | danger | `approve`/`approveChecked` with amount == u64 max, or ≫ balance |
| Authority transfer | danger | `setAuthority` where new authority is not the user |
| Account close to third party | danger | `closeAccount` with destination != user |
| Drains native balance | danger | native delta ≤ −(balance − rent-exempt minimum) |
| Unknown program | caution | program id not in the known table and not on the verified list |
| First interaction | caution | user has never signed for this program before (local history) |
| Token delegate set | caution | any `approve` at all |
| Simulation will fail | caution | `err != null` |
| Fee unusually high | info | priority fee > 10× the oracle's normal-tier bid |

The rules run on **decoded instructions plus simulated deltas**, never on one alone. An
instruction list without deltas misses CPI-hidden transfers; deltas without instructions cannot
tell an approval from a transfer.

### 3.5 Where it plugs in

`TransactionService.preview(...)` alongside the existing `estimate(...)`, then:

- `SendSolScreen` → preview before `ConfirmSendSheet`
- `SwapScreen` → preview the Jupiter payload (decode-only path, since Jupiter builds it)
- `StakeSolScreen` → preview
- F2 and F3 → preview is mandatory, not optional

---

## 4. F2 — Solana Pay

### 4.1 Two request kinds

```
solana:<recipient>?amount=&spl-token=&reference=&label=&message=&memo=   transfer request
solana:https://merchant.example/pay/1847?label=&message=                 transaction request
```

### 4.2 Algorithm

```
onScan(raw):
  1. if SolanaPayRequest.tryParse(raw)  -> TRANSFER
     if SolanaTransactionRequest.tryParse(raw) -> TRANSACTION
     else -> reject: not a Solana Pay URL

  TRANSFER:
    2. resolve decimals: native, or getMint(splToken)
    3. build ix: SystemInstruction.transfer
                 | TokenInstruction.transferChecked (derive both ATAs)
    4. if recipient ATA missing -> add createIdempotent, surface the rent cost
    5. append reference keys as read-only non-signer accounts   # merchant reconciliation
    6. append memo instruction if memo present
    7. preview -> approve -> TransactionService.sendAndConfirm

  TRANSACTION:
    2. GET link  -> {label, icon}    # show who is asking, before anything else
    3. show origin + label + icon, require explicit continue
    4. POST link {account: <wallet address>} -> {transaction: base64, message?}
    5. deserialize; VERIFY:
         - fee payer is the user
         - no signature slots for keys we do not control
         - message text is displayed, never trusted
    6. preview (decode-only; the merchant built it) -> approve
    7. sign -> sendAndConfirm
```

### 4.3 Non-negotiables

- The merchant's `label`/`message`/`icon` are **attacker-controlled strings**. Render them as
  untrusted content, never as authority. The origin host is the only trustworthy identity.
- `reference` keys are non-signer, non-writable. They exist so the merchant can find the
  transaction; they must never gain any other role.
- HTTPS only — the package enforces this on parse, and the check is not to be relaxed.

---

## 5. F3 — dApp Connect

### 5.1 Scheme

```
solfare://v1/connect
    ?dapp_encryption_public_key=<base58 x25519 pub>
    &cluster=mainnet-beta
    &app_url=<https origin>
    &redirect_link=<dapp scheme>

solfare://v1/signAndSendTransaction?dapp_encryption_public_key=&nonce=&payload=
solfare://v1/signTransaction        (same shape)
solfare://v1/signMessage            (same shape)
solfare://v1/disconnect
```

### 5.2 Handshake

```
connect:
  1. parse params; reject unless app_url is https and redirect_link is a registered scheme
  2. session_kp <- PrivateKey.generate()                      # per dapp, per connection
  3. shared     <- Box(myPrivateKey: session_kp, theirPublicKey: dapp_pub)
  4. show approval sheet: origin (app_url host), icon, the wallet being connected,
     and exactly what connecting grants (read address; ask to sign — never auto-sign)
  5. on approve: persist DappSession{ origin, dappPub, sessionPriv, walletId,
                                      createdAt, lastUsedAt, sessionToken }
  6. respond via redirect_link with:
        nonce   = random 24 bytes
        payload = box.encrypt({ public_key, session }, nonce)

signAndSendTransaction:
  1. look up session by dapp_encryption_public_key; reject if unknown/revoked
  2. plaintext <- box.decrypt(payload, nonce)      # auth failure = drop, no error detail
  3. tx <- deserialize(plaintext.transaction)
  4. VERIFY fee payer == our wallet; VERIFY no unknown required signers
  5. preview(tx)  -> approval sheet showing ORIGIN + deltas + risk flags
  6. on approve: sign -> TransactionService.sendAndConfirm (or confirmSigned)
  7. respond encrypted { signature }
  8. on reject: respond encrypted { errorCode: 4001, errorMessage: "User rejected" }
```

### 5.3 Threat model

| Threat | Defence |
|---|---|
| Phishing dapp mimicking a brand | Show the **origin host**, never the self-declared name, as the identity |
| Malicious payload disguised as a transfer | Preview from simulation, not from the dapp's description |
| Replay of a captured deeplink | Nonce is single-use; per-request id tracked and rejected on repeat |
| Session hijack after uninstall of the dapp | Sessions expire; user-visible list with one-tap revoke |
| Wallet drain via approvals | Risk engine flags unlimited approvals and authority changes as danger |
| Payload asks us to sign for another key | Reject any transaction whose fee payer is not our wallet |
| Silent signing | There is no auto-approve path. Ever. Every signature is a tap. |

Session private keys live in `flutter_secure_storage` next to the existing secrets, never in
shared preferences.

---

## 6. F4 — SPL token send + Token-2022

### 6.1 Mint inspection

```
getAccountInfo(mint, jsonParsed) -> data.parsed.info
  owner (program id)     -> Token vs Token-2022
  decimals
  extensions[]           -> { extension: "transferFeeConfig", state: {...} }
```

Extensions that change behaviour and therefore must change the UI:

| Extension | Effect |
|---|---|
| `nonTransferable` | Cannot be sent — block before the user types an amount |
| `transferFeeConfig` | Recipient receives less; show the net and the fee |
| `permanentDelegate` | Someone else can move this token at any time — caution flag |
| `transferHook` | Arbitrary program runs on transfer; extra CU, extra risk |
| `defaultAccountState` | New ATAs may land frozen |
| `interestBearingConfig` | Display balance ≠ raw balance |

### 6.2 Send algorithm

```
sendToken(mint, recipient, uiAmount):
  1. info <- mintInfo(mint)
  2. if info.nonTransferable: refuse with the reason
  3. amount <- uiAmount * 10^decimals            (integer math, no double rounding)
  4. srcAta <- findAssociatedTokenAddress(owner: me, mint)
  5. dstAta <- findAssociatedTokenAddress(owner: recipient, mint)
  6. ixs <- []
     if !exists(dstAta): ixs += createIdempotentAssociatedTokenAccount(...)
         # ~0.002 SOL rent, paid by sender — must be shown, never silent
  7. ixs += TokenInstruction.transferChecked(programId: info.programId,
              source: srcAta, mint: mint, destination: dstAta,
              owner: me, amount: amount, decimals: info.decimals)
  8. if info.transferFee != null:
         net <- amount - min(ceil(amount * bps / 10000), maxFee)
         show "recipient receives <net>"
  9. preview -> approve -> sendAndConfirm
```

`transferChecked` over `transfer` deliberately: it verifies decimals on chain, which turns a
decimals mistake into a rejected transaction instead of a 1000× transfer.

---

## 7. Build order

Dependency-ordered, each step shippable on its own:

1. **F1a** decoder + models — pure functions, unit-testable with no network
2. **F1b** preview engine on `simulateTransaction`
3. **F1c** risk engine
4. **F1d** `TxPreviewSheet`, wired into the existing send flow first
5. **F4** SPL send + Token-2022 (uses F1 for approval; the smallest real feature after it)
6. **F2** Solana Pay (transfer requests, then transaction requests)
7. **F3** dApp Connect (session layer, then each operation, preview already done)

F3 last on purpose: it is the largest, it is the one with an audience problem, and every piece of
it is safer once F1 is proven in production paths.

---

## 8. Open questions

1. **Verified program registry.** "Unknown program" needs a known-good list to be useful. Ship a
   bundled static list, or fetch one? A fetched list is a trust dependency and a network call on
   the approval path.
2. **Token metadata for deltas.** Symbols currently come from Helius DAS. Preview needs a symbol
   for an arbitrary mint, possibly offline. Cache per mint on first sight?
3. **Simulation on the critical path.** Preview adds ~300–800 ms before the confirm sheet. Show
   the sheet immediately with a skeleton, or hold until deltas resolve? (Recommend: skeleton, so
   a slow RPC never blocks the UI, with the approve button disabled until it lands.)
4. **F3 distribution.** No dapp speaks `solfare://` today. Ship it as a documented scheme with a
   demo dapp, or keep it internal until there is a partner?
5. **`preBalances` availability on Helius.** Confirmed on `api.mainnet-beta.solana.com`. The
   degraded path is designed but should be verified against the actual production RPC before F1b
   is called done.
