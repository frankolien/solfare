# Design — A market you can buy from

**Status:** proposed
**Date:** 2026-08

The market screen lists CoinGecko's global top 50 by market cap. Every row is a coin, not a
mint: `bitcoin`, `ethereum`, `tether`. There is a Tokens/Stocks toggle where Stocks changes a
heading and nothing else, and a sort menu behind a popup that reorders four ways.

Three problems, one cause.

- **Nothing is buyable.** A CoinGecko id does not name anything on Solana. There is no mint,
  so there is no route, so there can be no buy button. The token detail screen already admits
  this — Deposit, Swap and Limit are all `enabled: false`.
- **Stocks does not work** because there is no stock data behind it. The toggle was built
  before a source existed.
- **Sorting is hidden** in a popup anchored to a hardcoded screen position, and sorts by fields
  CoinGecko happens to return rather than the ones that decide whether an asset is worth
  touching.

The cause is the data source. Fix that and the other three fall out.

---

## 1. Research findings

Verified against the live APIs on 2026-08-09, not assumed.

### 1.1 Jupiter's token API returns everything a row needs, including the mint

`GET https://lite-api.jup.ag/tokens/v2/toptrending/24h?limit=100` returns, per token:

```
id (the mint)   name   symbol   icon   decimals   tokenProgram
circSupply  totalSupply  holderCount  mcap  fdv  usdPrice  liquidity
organicScore  organicScoreLabel  isVerified  tags  audit  firstPool
stats5m  stats1h  stats6h  stats24h
```

and each `statsN` block carries:

```
priceChange  holderChange  liquidityChange  volumeChange
buyVolume  sellVolume  buyOrganicVolume  sellOrganicVolume
numBuys  numSells  numTraders  numOrganicBuyers  numNetBuyers
```

`id` is the mint. That single field is what makes a buy possible, and it is the reason to move.
`decimals` and `tokenProgram` come with it, which is the rest of what an order needs.

Three feeds exist, all verified live:

| Feed | Path | Ordering |
|---|---|---|
| Trending | `/tokens/v2/toptrending/{window}` | price and volume momentum |
| Top traded | `/tokens/v2/toptraded/{window}` | 24h buy + sell volume |
| Organic | `/tokens/v2/toporganicscore/{window}` | `organicScore`, i.e. real traders over wash |

`{window}` is one of `5m`, `1h`, `6h`, `24h`.

### 1.2 Stats arrive for all four windows in one response

A token carries `stats5m`, `stats1h`, `stats6h` and `stats24h` together. The window chips do
**not** need a refetch — parse all four, let the UI pick. Refetching on every chip tap would be
three wasted round trips for data already in hand.

The feed selector is different: `/toptrending/1h` is a different ordering, not a different
projection of the same list. Changing feed or window changes which tokens come back, so that
one does refetch.

### 1.3 There is no category endpoint, and the tags lie about categories

`/tokens/v2/tag?query=stocks` → `{"status":400,"message":"Invalid tag provided."}`. Same for
`xstock`, `equity`, `commodity`, `rwa`. Only `verified` and `lst` are accepted.

Searching for the tag word does not work either — `search?query=xstocks` returns twenty
memecoins called STONK.

The tags *on* the tokens do include `stocks`, `equities`, `commodities`, `rwa` and `xstocks`,
but they cannot be used to build the shelves:

```
GLDx   Gold xStock    tags: xstocks, stocks, rwa, ...     ← gold, tagged stocks
PAXG   PAX Gold       tags: verified, rwa, token-2022     ← gold, tagged neither
XAUt0  Tether Gold    tags: commodities, rwa, verified    ← gold, tagged commodities
```

Three gold tokens, three different tag shapes. A commodities shelf built from tags would hold
one of them.

**Consequence:** the split has to be ours. A bundled registry maps mint → shelf, exactly like
`program_registry.dart` does for programs. It ships mints and shelves only, never prices.

### 1.4 The registry hydrates through the search endpoint

`GET /tokens/v2/search?query=<mint>,<mint>,<mint>` returns the full token object for each,
identical in shape to the feed responses. Verified with three mints; the documented ceiling is
100 per call, so the registry is chunked.

Spot-checked against the reference app on the same day: `SPYx 773.75` / screenshot `773.84`,
`PAXG 4361.11` / screenshot `4,361.11`. Same source, same numbers.

### 1.5 Registry contents, taken from live verified data

Every entry below came back with `isVerified: true` and at least one of the RWA tags. Nothing
here is from memory.

**Stocks** — xStocks (Backed Finance), 8 decimals, Token-2022:

```
SPYx    XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W    SP500
QQQx    Xs8S1uUs1zvS2p7iwtsG3b6fkhpvmwz4GYU3gWAmWHZ    Nasdaq
NVDAx   Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh    NVIDIA
CRCLx   XsueG8BtpquVJX9LVLLEGuViXUungE6WmK5YZ3p3bd1    Circle
TSLAx   XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB    Tesla
MSTRx   XsP7xzNPvEHS1m6qfanPUGjNmdnmsLKEoNAnHjdxxyZ    MicroStrategy
COINx   Xs7ZdzSHLU9ftNJsii5fCeJhoRWSC32SQGzGQtePxNu    Coinbase
HOODx   XsvNBAYkrDRNhA7wPHQfX3ZUXZyZLdnCQDfHZ56bzpg    Robinhood
GOOGLx  XsCPL9dNWBMvFtTmwcCA5v3xWPSMEBCszbQdiLLq6aN    Alphabet
MSFTx   XspzcW1PRtgf6Wj92HCiZdjzKCyFekVD8P5Ueh3dRMX    Microsoft
AMZNx   Xs3eBt7uRfJX8QUs4suhyU8p2M6DoUDrJyWBa8LLZsg    Amazon
PLTRx   XsoBhf2ufR8fTyNSjqfU71DYGaE6Z3SUGAidpzriAA4    Palantir
MCDx    XsqE9cRRpzxcGKDXj1BJ7Xmg4GRhZoyY1KpmGSxAWT2    McDonald's
AAPLx   XsbEhLAtcf6HdfpFZ5xEMdqW8nfAvcsP5bdudRLJzJp    Apple
AVGOx   XsgSaSvNSqLTtFuyWPBhK9196Xb9Bbdyjj4fH3cPJGo    Broadcom
METAx   Xsa62P5mvPszXL1krVUnU5ar38bBSVcWAB6fmPCo5Zu    Meta
BRK.Bx  Xs6B6zawENwAbWVi7w92rjazLuAr5Az59qgWKcNb45x    Berkshire Hathaway
ORCLx   XsjFwUPiLofddX5cWFHW35GCbXcSu1BCUGfxoQAQjeL    Oracle
AMDx    XsXcJ6GZ9kVnjqGsjBnktRcuwMBmvKWh8S93RefZ1rF    AMD
NFLXx   XsEH7wWfJJu2ZT3UCFeVfALnVA6CP5ur7Ee11KmzVpL    Netflix
JNJx    XsGVi5eo1Dh2zUpic4qACcjuWGjNv8GCt3dm5XcX6Dn    Johnson & Johnson
TQQQx   XsjQP3iMAaQ3kQScQKthQpx9ALRbjKAjQtHg6TFomoc    TQQQ
```

**Commodities** — precious metals:

```
XAUt0   AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P   Tether Gold        6dp
PAXG    5GgRAEmv8ZxF2PR5hY72Qs5x1bnQ6UK2RbTPoqJ3wSwW   PAX Gold           6dp
GLDx    Xsv9hRk1z5ystj9MhnA7Lq4vjSsLwzL2nxrwmwtD3re    Gold xStock        8dp
GLDon   hWfiw4mcxT8rnNFkk6fsCQSxoxgZ9yVhB6tyeVcondo    SPDR Gold (Ondo)   9dp
IAUon   M77ZvkZ8zW5udRbuJCbuwSwavRa7bGAZYMTwru8ondo    iShares Gold (Ondo) 9dp
SLVx    XsxAd6okt8y1RRK6gNg7iJaqiWNiq5Md5EDf3ZrF2dm    iShares Silver     8dp
PPLTx   Xst6eFD4YT6sz9RLMysN9SyvaZWtraSdVJQGu5ZkAme    abrdn Platinum     8dp
```

Decimals and names are hydrated, not bundled — the table above is provenance, not a source of
truth for the app.

### 1.6 Nothing serves price history for these mints

`datapi.jup.ag/v1/charts/{mint}` is 404 for every shape tried. CoinGecko has no listing for
xStocks at all. So the token detail chart, which today asks CoinGecko for
`/coins/{id}/market_chart` using the CoinGecko id, has no equivalent once `id` becomes a mint.

This is a real cost of the move and it gets handled rather than papered over — see §4.

---

## 2. Shape

```
                    Jupiter token API v2 (lite-api.jup.ag)
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
      /toptrending/{w}      /toptraded/{w}       /search?query=<mints>
      /toporganicscore/{w}                               │
              │                     │                    │
              └──────────┬──────────┘         TokenizedAssetRegistry
                         │                     (mint → shelf, bundled)
                         │                              │
                         └──────────┬───────────────────┘
                                    │
                          JupiterTokenDataSource
                          MarketToken.fromJupiter
                                    │
                               MarketBloc
                    (category · feed · window · sort · search)
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
              MarketScreen                    TokenDetailScreen
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                                BuySheet
                                    │
                              SwapExecutor
                    (Jupiter /order?taker → sign → /execute)
                                    │
                              PreviewEngine
                     (simulate the built route before signing)
```

`SwapExecutor` is new but not new work: it is the order/sign/execute body lifted out of
`SwapBloc` so the buy sheet and the swap screen share one copy of the v0 signature patching and
the confirm-on-timeout fallback.

---

## 3. Algorithms

### 3.1 Loading a category

```
load(category, feed, window):
    if cache has (category, feed, window) and it is younger than 30s:
        emit cached
        return

    if category is tokens:
        rows ← GET /tokens/v2/{feed}/{window}?limit=100
    else:
        mints ← registry.mintsFor(category)
        rows  ← concat over chunks of 100:
                    GET /tokens/v2/search?query=<chunk joined by ','>

    rows ← rows where the guard passes            (§3.2)
    cache[(category, feed, window)] ← rows
    emit rows
```

The registry categories ignore `feed` — a curated shelf has no trending ordering to ask for.
They are sorted client-side like everything else.

### 3.2 The registry guard

A bundled mint is a claim about the world made at build time. The world moves.

```
guard(row, claimedShelf):
    reject if not row.isVerified
    reject if row.tags ∩ {stocks, equities, commodities, rwa, xstocks} is empty
    reject if row.usdPrice is null or 0
    accept
```

A mint that stops being a verified real-world asset drops off the shelf instead of sitting
there mislabelled with a stale price. Dropping is the correct failure: an empty shelf is
honest, a wrong one is not.

### 3.3 Sorting

```
sort keys: marketCap · volume · priceChange · liquidity · holders · organicScore
```

`volume` and `priceChange` read from the stats block of the **selected window**, so the same
sort key means something different under 5m than under 24h. That is the point of the chips.

```
compare(a, b, key, window):
    va ← extract(a, key, window)
    vb ← extract(b, key, window)
    nulls sort last regardless of direction   ← a missing value is not "smallest"
    return descending ? vb-va : va-vb
```

Tapping the active column flips its direction; tapping a different one starts descending. Price
change flipped is the losers view, so it comes for free rather than as its own menu entry.

One key is not a measurement: `rank` means "the order the feed returned". Trending is a ranking
Jupiter computes from data it does not publish, so it cannot be reproduced client-side — the
only way to show it is to leave the list alone. `rank` therefore reverses rather than sorts,
because Dart's sort is not stable and running it over values that all compare equal would
shuffle the very ordering being preserved. Registry shelves have no ranking of their own and
open on market cap instead.

### 3.4 Buying

```
buy(asset, payWith, amount):
    lamports ← amount × 10^payWith.decimals

    order ← GET /swap/v2/order?inputMint=payWith.mint
                              &outputMint=asset.mint
                              &amount=lamports
                              &slippageBps=50
                              &taker=wallet
    if order.transaction is empty: fail with order.errorMessage

    signed  ← patch our signature into slot 0 of the v0 transaction
    preview ← PreviewEngine.previewSigned(signed, wallet)

    show the preview and wait
    if the user declines: stop, nothing was broadcast

    result ← POST /swap/v2/execute {signedTransaction, requestId}
    if result.status is Success: done
    if result carries a signature: confirm it against the chain ourselves
    otherwise: fail
```

Signing before showing the preview looks backwards and is not. The signature is a local
operation; nothing reaches the network until `/execute`. Simulating the route Jupiter actually
built is the only way to show the user the balances that will really move, rather than
Jupiter's own quote of them. This is the same rule F1 was built on: the preview reports what
the transaction does, not what the party proposing it says it does.

The preview will usually report `Instructions could not be read` — a Jupiter route is a v0
message over address lookup tables we do not hold. The balance deltas still come from
simulation and stand on their own, which is the part that matters here.

### 3.5 Insufficient balance

```
maxSpendable(payWith, balance):
    if payWith is native SOL: max(0, balance − 0.01 SOL)
    else: balance
```

The reserve keeps enough SOL behind to pay the fee and the ATA rent for the token being bought,
which for a first purchase of any asset is the difference between the swap landing and failing
after the user has already approved it.

---

## 4. The chart, honestly

`MarketToken.id` stops being a CoinGecko id and becomes a mint. The detail chart cannot follow.

- Tokens that CoinGecko does list are resolvable through
  `/coins/solana/contract/{mint}`, which returns the coin including its id. One extra call,
  cached, and the existing chart path is unchanged after it.
- xStocks and the Ondo tokens are not listed anywhere with history. For those the chart is
  replaced by the stats Jupiter does return — liquidity, holders, organic score, buy versus
  sell volume for the window. That is more than the chart said and none of it is invented.

Drawing a flat line, or a line built from a single current price repeated, would be worse than
showing no chart. It would look like data.

---

## 5. Scope

In:

- Jupiter token API v2 as the market data source, all four windows parsed per token
- Three token feeds: trending, top traded, organic
- Stocks and Commodities shelves from a bundled registry, hydrated live, guarded
- Sorting by six keys, per-window, with direction, from tappable column headers
- Buy sheet: presets, live quote, balance, insufficient-balance state, preview, execute
- `SwapExecutor` extracted from `SwapBloc` and shared
- Token detail: Buy and Swap wired, Send made mint-aware, chart fallback

Out, and deliberately:

- Limit orders. Jupiter's limit order API is a separate program and a separate approval story.
  The button stays disabled rather than becoming a lie.
- Earn. Nothing in the wallet stakes or lends yet.
- Energy and agriculture commodity shelves. No verified mints found for either. An empty shelf
  with "Soon" on it is a promise, and this document does not make promises the code cannot keep.

---

# Part two — the market as a home, not a list

**Status:** proposed
**Date:** 2026-08-09

Part one made every row buyable and every column sortable. It left the market as one long list
behind a category tab, which is the right shape for *browsing a shelf* and the wrong shape for
*arriving*. Someone opening the tab wants to see what they follow, what is moving, and what the
wallet actually offers — not the top of one list with the rest folded away behind a tab bar.

So the market becomes two screens:

- **Home** — sections. Watchlist, Trending, Major crypto, Stocks, ETFs, Commodities, Most
  traded. Each shows a handful and a chevron.
- **List** — the screen from part one, reached by that chevron. Windows, sortable columns, the
  whole shelf. Nothing built in part one is thrown away; it moves one level down, which is
  where a sortable table belongs.

## 6. Research findings

Verified live on 2026-08-09.

### 6.1 The shelves that were missing have deep mints

Part one had Stocks and Commodities. The layout needs Major crypto and ETFs too, and both
exist:

```
WBTC   3NZ9JMVBmGAqocybic2c7LQCJScmgsAZ6vQqTDzcqmJh   Wrapped BTC (Portal)   liq 29.3M
cbBTC  cbbtcf3aa214zXHbiAZQwf4122FBYbraNdFqgw4iMij    Coinbase Wrapped BTC   liq 22.3M
ETH    7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs   Ether (Portal)         liq 13.5M
```

The ETF shelf is mostly what part one filed under Stocks. `GLDx` is the SPDR Gold Shares ETF,
not a company, and `SPYx` and `QQQx` are indices. They move to ETFs. Physical gold — `XAUt0`,
`PAXG` — stays under Commodities, which is the distinction the reference layout draws too: a
Gold card at the spot price and an SPDR Gold Shares card at the fund price are two different
things.

### 6.2 A company can have five issuers, and liquidity is the tiebreak

SpaceX alone:

```
SPCX     Backpack Securities   SPCXxcqXj6e5dJDVNovHN8744zkbhM2bYudU45BimGb   liq 516,401
SPCXx    xStock                Xs3oZwbHvqis4NYcf4YKWmEia2eC84wSiVrcYcTqpH8   liq 502,910
SPACEX   PreStocks             PreANxuXjsy2pvisWWMNB6YaJNzr7681wJJr2rHsfTh   liq  88,809
tSpaceX  Tessera               TSPXcLV76s6V2zDiZQ18kBfcbnjaE2ZzNT3ga2Pd99v   liq  68,932
SPCXon   Ondo                  wzAyQTorWyoVXuJKj2x8EqKEGJpS13z6EWE9z5Aondo   liq      49
```

All five verified, all five tagged `stocks`. The registry picks one per company, by liquidity,
because liquidity is what decides whether a purchase fills at the price on the card.

Two corrections to part one's registry fall out of the same check:

- `SLVx` has 12 dollars of liquidity; `SLVon` has 46,202. Silver moves to the Ondo mint.
- `PPLTx` and `PPLTon` are both zero, and an order against `PPLTx` answers `Quote not
  available from market maker`. Platinum comes off the shelf. Part one shipped it with a
  message explaining why it could not be bought; not listing it is the better answer.

Pre-IPO names are real and liquid enough to list:

```
ANTHROPIC  Pren1FvFX6J3E4kXhJuCiAD5aDmGEb7qJRncwA8Lkhw   liq 587,627
OPENAI     PreweJYECqtQwBtpxHL171nL2K6umo692gTm7Q3rpgF   liq 229,965
```

### 6.3 The API name carries the issuer, and the card has no room for it

`SP500 xStock`, `Tesla xStock`, `SpaceX - Backpack Securities`, `iShares Silver Trust (Ondo
Tokenized)`. On a card the size of a thumbnail that is mostly wrapper.

So a display name, derived by rule rather than hand-written per entry:

```
displayName(name, override):
    if override exists: return override
    strip a trailing issuer suffix:
        " xStock" | " PreStocks" | " - Backpack Securities"
        | " (Ondo Tokenized)" | " (Ondo Token)" | " Ondo"
    return what is left
```

Overrides exist only where the stripped name is still not what a person calls the thing:
`SPYx` → S&P 500, `QQQx` → Nasdaq 100, `WBTC` → Bitcoin, `ETH` → Ethereum, `XAUt0` → Gold.

The full API name stays on `MarketToken.name` and is what the detail screen shows, because
"which issuer" is exactly the question worth answering before buying a tokenised equity.

## 7. Shape

```
                              MarketHomeScreen
                                     │
        ┌────────────┬───────────────┼───────────────┬────────────┐
        │            │               │               │            │
   TickerStrip   Watchlist       Trending       Major crypto   Stocks
        │            │           Most traded     ETFs · Commodities
        │            │               │               │
        │      WatchlistStore    MarketFeed      TokenizedAssetRegistry
        │      (mints on disk)   (live rank)     (mints → shelf)
        │            │               │               │
        └────────────┴───────┬───────┴───────────────┘
                             │
                     MarketHomeBloc
              (one load per section, in parallel)
                             │
                    JupiterTokenDataSource
                             │
                             ▼
                     MarketListScreen  ← the chevron
                  (windows · sortable columns · the full shelf)
```

## 8. Algorithms

### 8.1 Loading the home

```
loadHome():
    sections ← [trending, majorCrypto, stocks, etfs, commodities, mostTraded]
    run in parallel:
        for each section: load its source, take the first N
    emit each as it lands

    watchlist is local: read the mints, then hydrate them like any shelf
```

Sections land independently. One slow feed must not hold up five that already answered, and a
section that fails is one empty card rather than an empty screen — the home is six sources and
treating them as one transaction makes it as reliable as the worst of them.

### 8.2 The watchlist

Mints on disk, in shared preferences rather than secure storage: a list of things somebody
finds interesting is not a secret, and putting it in the keychain would mean the wallet cannot
read it without unlocking.

```
star(mint):   set ← read; set.add(mint);    write; notify
unstar(mint): set ← read; set.remove(mint); write; notify
```

A notifier rather than a bloc, because every star in the app has to flip at once — the row, the
detail header, and the home section are three places showing one fact.

Ordering is insertion order, not market cap. It is the user's list.

### 8.3 The ticker strip

A marquee of what is moving. Source: the watchlist when it has anything, otherwise Major crypto
plus the most liquid stocks. It scrolls; it is not interactive beyond a tap through to detail.

Deliberately not: a live socket. The strip re-reads whatever the home already loaded. A second
price stream for decoration would be a second thing to keep in sync and a second thing to
mislead people when it drifts.

### 8.4 The warning badge

An orange mark on the icon, on one rule:

```
warn(token) = not token.isVerified
```

Trending is where a wallet meets tokens nobody has checked, and that is the one place the
distinction has to be visible without tapping through. Organic score is a better signal of wash
trading, but it is a number without a threshold anyone agreed on, and inventing one to drive a
warning icon would be dressing a guess as a finding.

## 9. Scope

In: the two screens, the four shelves, the watchlist, the ticker strip, display names, the
warning badge, and a disclaimer footer saying what a tokenised equity is and is not.

Out: Cards and Earn tabs, price alerts, and any section the wallet cannot fill with real mints.

---

# Part three — the token screen

**Status:** proposed
**Date:** 2026-08-09

The detail screen has the right information in the wrong shape: four small action circles where
one decision belongs, a header with a dead star and a dead overflow, and a chart whose
timeframe labels do not describe the data behind them.

## 10. Research findings

### 10.1 Two of the five timeframe chips cannot be honest

The chart asks CoinGecko for `/market_chart?days=N`, whose granularity is fixed by the range:
five-minute points for `days ≤ 1`, hourly to ninety days, daily beyond. So the finest thing the
chart can draw is a five-minute candle.

The chips today are labelled `1m 1H 1D 1W 1M` over `days = 0.04 0.08 1 7 30`. The first two are
already wrong: `1m` fetches an hour of five-minute points, `1H` fetches two hours of them.

Relabelled to what the request actually returns:

```
1H  days=0.04     4H  days=0.17     1D  days=1     1W  days=7     1M  days=30
```

A `1s` chip drawing five-minute candles would be a chip that lies about its own axis, so there
is not one.

### 10.2 Bridging has a real destination and no integration

`jup.ag/bridge` is a 404. `portalbridge.com` — Wormhole's own front end, the canonical route
onto Solana from another chain — answers 200, as do deBridge and Jumper.

Solfare has no bridge integration and is not getting one here. What it has is
`DappBrowserScreen(initialUrl:, title:)`. So Bridge opens Portal in that browser: a real
destination, in-app, rather than a row that does nothing.

### 10.3 Sharing needs no new dependency

`share_plus 12.0.2` is already in the project and already used by the receive screen and the
transaction history. `ShareParams` takes `files: List<XFile>` alongside `text`, and
`path_provider` is present for the temp file. A card rendered under a `RepaintBoundary`,
captured to PNG and handed to the system sheet needs nothing new installed.

## 11. Shape

```
TokenDetailScreen
  ├── header:  ✕   logo · name   ★ watchlist   ⇪ share   ⋮ more
  │                                                        └── Add funds
  │                                                              └── sheet
  │                                                                   ├── Receive crypto
  │                                                                   └── Bridge → Portal
  ├── price + change over the selected window
  ├── chart (line | candles), timeframes 1H 4H 1D 1W 1M
  ├── market cap · volume 24h · liquidity
  ├── about
  ├── mint address (copy) · ticker
  ├── homepage · X
  └── Buy  ─────────────────────────────► swap sheet, output preset to this token
```

Four action circles become one primary control plus an overflow. Deposit and Swap were only
ever ways of getting to two screens that already exist; Buy is the thing the screen is for.

## 12. Algorithms

### 12.1 Buy opens the swap that already works

```
buy(token):
    output ← SwapToken(mint, symbol, name, decimals, icon)   from the market row
    present SwapScreen modally with output preset
```

Not a second swap surface. The screen underneath is the one with the balance handling, the
reserve, the quote refresh and the Jupiter execute path already tested on device. Presetting
its output is the whole change.

The buy sheet from part two stays for the shelves, where the question is "put fifty dollars
into this" rather than "trade this pair" — but the token screen's Buy is a swap, because that
is what the reference does and what the mint deserves: a pair, a rate, and a slippage setting.

### 12.2 Sharing a token

```
share(token):
    render the card off-screen under a RepaintBoundary
    wait one frame so it has painted
    image ← boundary.toImage(pixelRatio: 3)
    png   ← image.toByteData(format: png)
    write png to a temp file
    SharePlus.share(files: [png], text: "<name> on Solfare — <mint>")
```

Everything on the card comes from what the screen is already showing. A share image is a claim
that travels further than the screen it came from, so it gets no number the screen does not
have.

## 13. Scope

In: the header row with a live star, share and overflow; honest timeframes; the stats row; the
mint/ticker block; Buy as a preset swap; Add funds → Receive or Bridge.

Out: limit orders, price alerts, and a `1s` chart. The first two have no implementation, the
third has no data.
