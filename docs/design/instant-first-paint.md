# Instant first paint

The app should open showing your balance, not fetching it.

## What happens today

`_onFetchBalance` opens with an unconditional `emit(const WalletLoading())` and
only then calls the RPC. The SOL price does the same. So every cold start
paints an empty or spinning card for as long as the network takes, and the
number the user came to see arrives last.

Tokens and NFTs already do the right thing — both read a SharedPreferences
cache, emit it, then fetch and overwrite:

    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) emit(TokensFetched(_decodeTokens(cachedJson)));
    ...
    await prefs.setString(cacheKey, _encodeTokens(tokens));

So the pattern is already in this codebase. Balance and price never got it.

The homepage compounds it. `_resolveData` starts from `_cachedBalanceInSol`
and friends, which is why the number survives bloc churn *within* a session —
but those are `State` fields initialised to `0.0`, so a cold start begins at
zero every time.

## The design

One store, the same shape as the token cache, keyed by address.

    class PortfolioCache {
      static Future<Snapshot?> read(String address);
      static Future<void> write(String address, {
        required int lamports,
        required double priceUsd,
        required double priceChange24h,
      });
    }

Stored per address, because showing wallet A's balance under wallet B's name
for the half-second before the fetch lands is worse than showing nothing.

Written from the one place both numbers are already known together —
`_pushWalletWidget` already waits for exactly that pairing to feed the iOS
widget, so the cache is written alongside it rather than from two racing
callers.

Read at activation, before the network call:

1. `_activateWallet` reads the cache for that address.
2. If present, emit `BalanceFetched` and `SolPriceFetched` immediately, marked
   `fromCache: true`.
3. Then fetch as it does today. Fresh values overwrite.
4. `WalletLoading` is emitted only when there is no cached value — a first-ever
   launch has nothing to show and should say so.

The homepage needs no change of its own. `_resolveData` already folds
`BalanceFetched` and `SolPriceFetched` into its `_cached*` fields, so the
emission above populates them — one source of truth rather than the screen and
the bloc each reading the store.

**Reset on switch.** `_lastLamports` has to be cleared at the top of
`_activateWallet`. It was not, and the consequence is worse than a stale
number: with a value left over from the previous wallet, the new wallet
suppresses its own loading state and shows the old balance, and
`_pushWalletWidget` — which reads the *current* active wallet — can write that
balance into the new wallet's cache, making it persist. The SOL price is the
same everywhere and stays.

## Staleness

A cached balance is a claim about the past. Two places must not treat it as
present tense:

- **Sending.** The amount validation and the "Max" button read the balance from
  state. A stale, higher number would let the user compose a send they cannot
  afford. The simulation on the confirm sheet is the authority and would reject
  it — the transaction fails before signing, costing nothing — but the error
  arrives late and reads like a bug. So the send screen requests a fresh
  balance on entry and treats a cached one as "not yet known" for validation.
- **After a send.** The cache is written on every balance change, so a
  confirmed send updates it. Nothing to do beyond not skipping the write.

Everything else — the card, the portfolio row, the widget — is display, and a
two-second-old balance shown instantly beats a correct one shown late.

`fromCache` is carried on the state rather than inferred from a timestamp, so
the UI can decide without every widget re-implementing an age threshold.

## What is deliberately not cached

The transaction history and stake accounts. Both are lists whose staleness is
visible and confusing — a pending transaction that vanishes on refresh, a
stake account that reappears after being withdrawn. They keep their loading
states.

## Tests

Covered at the store: round-trip, one address never serving another, a miss
rather than a zero, truncated and unparseable entries surviving as misses.

Not covered: the emission order inside `WalletBloc`, because there is no test
harness for it — `SolanaRpcDataSource` is a wide interface with nothing mocking
it today, which the audit already lists as a gap. The two behaviours that go
unverified are "cached values are emitted before the first RPC call" and "no
loading state is emitted when something is cached". Both were checked by hand,
neither is pinned down.
