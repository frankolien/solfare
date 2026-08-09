#!/usr/bin/env python3
"""Generate the Solfare system-design .excalidraw scene.

Every label is a CONTAINER-BOUND text element (containerId + boundElements),
so Excalidraw owns wrapping and centering. Cards auto-size to their content
and sections are laid out on a tracked cursor, so nothing overlaps.
"""
import json

INK = "#1e1e1e"
MUTE = "#5c5f66"

# stroke / fill pairs
BLUE = ("#1971c2", "#a5d8ff")
GREEN = ("#2f9e44", "#b2f2bb")
YELLOW = ("#f08c00", "#ffec99")
RED = ("#e03131", "#ffc9c9")
PURPLE = ("#6741d9", "#d0bfff")
TEAL = ("#0c8599", "#99e9f2")
GREY = ("#495057", "#e9ecef")
PLAIN = (INK, "transparent")

CODE = 3          # Cascadia — the structured, technical look
PAD = 12          # inner padding for card text
CHAR_W = 0.60     # code-font average advance, in em
LINE_H = 1.25

elements = []
_seq = [0]


def _next():
    _seq[0] += 1
    return _seq[0]


def _el(kind, x, y, w, h, stroke=INK, bg="transparent", **extra):
    n = _next()
    el = {
        "id": "el%04d" % n,
        "type": kind,
        "x": round(x), "y": round(y), "width": round(w), "height": round(h),
        "angle": 0,
        "strokeColor": stroke,
        "backgroundColor": bg,
        "fillStyle": "solid",
        "strokeWidth": 1,
        "strokeStyle": "solid",
        "roughness": 1,
        "opacity": 100,
        "groupIds": [],
        "frameId": None,
        "index": "a%04d" % n,
        "roundness": {"type": 3} if kind == "rectangle" else None,
        "seed": 100000 + n * 7919,
        "version": 1,
        "versionNonce": 200000 + n * 104729,
        "isDeleted": False,
        "boundElements": [],
        "updated": 1735689600000,
        "link": None,
        "locked": False,
    }
    el.update(extra)
    elements.append(el)
    return el


def _text_el(x, y, w, h, s, size, color, align, valign, container_id):
    return _el(
        "text", x, y, w, h, stroke=color,
        text=s, fontSize=size, fontFamily=CODE, textAlign=align,
        verticalAlign=valign, containerId=container_id, originalText=s,
        autoResize=False, lineHeight=LINE_H,
    )


def label(x, y, s, size=14, color=INK, align="left"):
    """Free-standing text (headings, notes). Not bound to any container."""
    w = max(len(l) for l in s.split("\n")) * size * CHAR_W
    h = len(s.split("\n")) * size * LINE_H
    if align == "center":
        x -= w / 2
    t = _text_el(x, y, w, h, s, size, color, align, "top", None)
    t["autoResize"] = True
    return t


def measure(lines, size):
    w = max(len(l) for l in lines) * size * CHAR_W + PAD * 2
    h = len(lines) * size * LINE_H + PAD * 2
    return w, h


def card(x, y, title, body=(), color=PLAIN, size=12, width=None, min_h=0):
    """A titled box with bound, centered text. Returns the rectangle."""
    stroke, bg = color
    lines = [title] + list(body)
    text = "\n".join(lines)
    w, h = measure(lines, size)
    w = max(width or 0, w)
    h = max(min_h, h)

    rect = _el("rectangle", x, y, w, h, stroke=stroke, bg=bg)
    txt = _text_el(x + PAD, y + PAD, w - PAD * 2, h - PAD * 2,
                   text, size, stroke, "center", "middle", rect["id"])
    rect["boundElements"] = [{"id": txt["id"], "type": "text"}]
    return rect


def note(x, y, title, body=(), color=RED, width=None, size=12):
    """A wide callout — the rules that matter, not a node in a flow."""
    return card(x, y, title, body, color=color, size=size, width=width)


def _edge(el, side):
    x, y, w, h = el["x"], el["y"], el["width"], el["height"]
    return {
        "r": (x + w, y + h / 2), "l": (x, y + h / 2),
        "t": (x + w / 2, y), "b": (x + w / 2, y + h),
    }[side]


def connect(a, b, from_side="r", to_side="l", color=INK, text=None, dashed=False, gap=8):
    x1, y1 = _edge(a, from_side)
    x2, y2 = _edge(b, to_side)
    dx = {"r": gap, "l": -gap, "t": 0, "b": 0}[from_side]
    dy = {"t": -gap, "b": gap, "r": 0, "l": 0}[from_side]
    ex = {"r": gap, "l": -gap, "t": 0, "b": 0}[to_side]
    ey = {"t": -gap, "b": gap, "r": 0, "l": 0}[to_side]
    x1, y1, x2, y2 = x1 + dx, y1 + dy, x2 + ex, y2 + ey

    arw = _el("arrow", x1, y1, abs(x2 - x1), abs(y2 - y1), stroke=color,
              points=[[0, 0], [round(x2 - x1), round(y2 - y1)]],
              lastCommittedPoint=None,
              startBinding={"elementId": a["id"], "focus": 0, "gap": gap},
              endBinding={"elementId": b["id"], "focus": 0, "gap": gap},
              startArrowhead=None, endArrowhead="arrow", elbowed=False)
    if dashed:
        arw["strokeStyle"] = "dashed"
    a["boundElements"] = a.get("boundElements", []) + [{"id": arw["id"], "type": "arrow"}]
    b["boundElements"] = b.get("boundElements", []) + [{"id": arw["id"], "type": "arrow"}]

    if text:
        # Bound arrow labels sit at the midpoint and never collide.
        w = len(text) * 11 * CHAR_W + 8
        t = _text_el((x1 + x2) / 2 - w / 2, (y1 + y2) / 2 - 9, w, 18,
                     text, 11, color, "center", "middle", arw["id"])
        arw["boundElements"].append({"id": t["id"], "type": "text"})
    return arw


def row(x, y, specs, gap=26, size=12, width=None):
    """Lay cards left-to-right, return them and the row's height."""
    out, cx, tallest = [], x, 0
    for spec in specs:
        c = card(cx, y, spec[0], spec[1], spec[2], size=size, width=width)
        out.append(c)
        cx += c["width"] + gap
        tallest = max(tallest, c["height"])
    return out, tallest


def chain(cards, color=INK, labels=None):
    for i in range(len(cards) - 1):
        connect(cards[i], cards[i + 1], "r", "l", color=color,
                text=(labels[i] if labels else None))


def section(x, y, n, heading, sub):
    label(x, y, "%d. %s" % (n, heading.upper()), size=22)
    label(x, y + 34, sub, size=13, color=MUTE)
    return y + 74


# ═══════════════════════════════════════════════════════════════════
L, R = 120, 1780          # two column anchors
elements_start_y = 120

label(L, 40, "SOLFARE — WALLET PLATFORM SYSTEM DESIGN", size=30)
label(L, 84, "Four features on one spine. Every signature passes through one preview and one sender.",
      size=14, color=MUTE)

# ─── 1. Architecture ───────────────────────────────────────────────
y = section(L, 150, 1, "Architecture — where the new pieces live",
            "Starred boxes do not exist yet. Everything else is already in the codebase.")

layers = [
    ("PRESENTATION", [
        ("SendSolScreen", ["existing"], BLUE),
        ("SwapScreen", ["existing"], BLUE),
        ("StakeSolScreen", ["existing"], BLUE),
        ("QrScannerScreen", ["existing"], BLUE),
        ("TxPreviewSheet *", ["one approval", "surface for all"], BLUE),
    ]),
    ("BLOC", [
        ("WalletBloc", ["existing"], PURPLE),
        ("SwapBloc", ["existing"], PURPLE),
        ("StakingBloc", ["existing"], PURPLE),
        ("PayBloc *", ["Solana Pay"], PURPLE),
        ("DappBloc *", ["session +", "request queue"], PURPLE),
    ]),
    ("CORE SERVICES", [
        ("TransactionService", ["build · price", "send · confirm"], GREEN),
        ("PreviewEngine *", ["simulate ->", "balance deltas"], GREEN),
        ("RiskEngine *", ["decoded ix +", "deltas -> flags"], GREEN),
        ("TokenService *", ["ATA derive", "Token-2022"], GREEN),
        ("SessionManager *", ["x25519 ECDH", "sealed box"], GREEN),
    ]),
    ("DATA", [
        ("SolanaRpcDataSource", ["simulate · fees", "status · accounts"], YELLOW),
        ("JupiterDataSource", ["order · execute"], YELLOW),
        ("Helius DAS", ["tokens · NFTs"], YELLOW),
        ("SecureStore", ["mnemonic", "session keys"], YELLOW),
    ]),
]
for name, cells in layers:
    label(L, y + 24, name, size=13, color=MUTE)
    cards, tall = row(L + 190, y, cells, width=230)
    if name != "DATA":
        connect(cards[0], None, gap=0) if False else None
    y += tall + 46

label(L, y - 30, "*  new in this design", size=12, color=MUTE)

note(L, y, "ONE APPROVAL SURFACE, ONE SENDER", [
    "Send, swap, stake, Solana Pay and dApp Connect all end at the same TxPreviewSheet,",
    "fed by the same TxPreview. TransactionService stays the only code that broadcasts.",
    "Four confirm screens would mean four places for a drainer to find a gap.",
], color=RED, width=1180)
y += 130

# ─── 2. F1 preview pipeline ────────────────────────────────────────
y = section(L, y + 30, 2, "F1 — Transaction preview (the spine)",
            "Nothing gets signed without passing through here.")

p1 = card(L, y, "INSTRUCTIONS", ["+ signers", "+ fee payer"], GREY, width=200)
p2 = card(L + 260, y, "SIGN PROBE", ["valid wire format", "sigVerify is off"], GREY, width=230)
p3 = card(L + 550, y, "simulateTransaction", ["replaceRecentBlockhash", "innerInstructions: true"], GREEN, width=290)
chain([p1, p2, p3])

vy = y + p3["height"] + 60
outs, tall = row(L, vy, [
    ("preBalances / postBalances", ["native SOL, per account"], GREEN),
    ("pre/postTokenBalances", ["mint · owner · decimals"], GREEN),
    ("logs + innerInstructions", ["where CPI hides transfers"], GREEN),
    ("err · fee · unitsConsumed", ["real fee, not an estimate"], GREEN),
], width=280)
connect(p3, outs[1], "b", "t", color=GREEN[0])

nt = note(L, vy + tall + 40, "VERIFIED ON MAINNET, NOT ASSUMED", [
    "A real versioned transaction simulated against api.mainnet-beta returned all four of these directly.",
    "No getMultipleAccounts pre-state fetch, no hand-rolled account diffing. It is the same shape",
    "getTransaction meta uses, which SolanaRpcDataSourceImpl already parses for transaction history.",
], color=TEAL, width=1180)

dy = vy + tall + 40 + nt["height"] + 55
d1 = card(L, dy, "BalanceDelta[]", ["signed, per mint", "own accounts first"], BLUE, width=250)
d2 = card(L + 310, dy, "InstructionDecoder", ["program id + data byte", "unknown stays unknown"], BLUE, width=290)
d3 = card(L + 700, dy, "RiskEngine", ["deltas AND decoded", "never one alone"], RED, width=270)
connect(outs[0], d1, "b", "t", color=BLUE[0])
connect(outs[2], d2, "b", "t", color=BLUE[0])
connect(d1, d3, "r", "l", color=RED[0])
connect(d2, d3, "b", "b", color=RED[0])

sy = dy + d3["height"] + 60
s1 = card(L + 310, sy, "TxPreviewSheet", ["deltas · flags · fee", "approve or reject"], YELLOW, width=290)
s2 = card(L + 700, sy, "TransactionService", ["sendAndConfirm"], GREEN, width=270)
connect(d3, s1, "b", "t")
connect(s1, s2, "r", "l", text="approve")

note(L, sy + 130, "DECODING RULE", [
    "Never invent a friendly name for a program we",
    "do not recognise. \"Unknown program\" is a fact.",
    "\"Swap\" would be a lie a drainer can exploit.",
], color=RED, width=430)

y = sy + 260

# ─── 3. Risk rules ─────────────────────────────────────────────────
y = section(L, y, 3, "F1 — Risk rules",
            "Evaluated on decoded instructions AND simulated deltas together.")

r1, tall = row(L, y, [
    ("DANGER", [
        "unlimited approval  (u64 max or >> balance)",
        "authority transfer  (setAuthority, not us)",
        "close to third party  (closeAccount)",
        "drains native balance  (below rent-exempt)",
    ], RED),
    ("CAUTION", [
        "unknown program  (not in known table)",
        "first interaction  (no local history)",
        "token delegate set  (any approve)",
        "simulation will fail  (err != null)",
    ], YELLOW),
    ("INFO", [
        "fee unusually high",
        "(> 10x the oracle's normal-tier bid)",
    ], GREY),
], width=430)
y += tall + 60

# ─── 4. F4 token send ──────────────────────────────────────────────
y = section(L, y, 4, "F4 — SPL send + Token-2022",
            "Today the wallet displays tokens and cannot send a single one.")

t1 = card(L, y, "mint address", [], GREY, width=180)
t2 = card(L + 240, y, "getAccountInfo", ["jsonParsed"], GREY, width=210)
t3 = card(L + 510, y, "extensions[]", ["+ owning program", "Token vs Token-2022"], PURPLE, width=260)
chain([t1, t2, t3])

gy = y + t3["height"] + 55
gates, tall = row(L, gy, [
    ("nonTransferable", ["block before the user", "types an amount"], RED),
    ("transferFeeConfig", ["recipient gets less —", "show the net"], YELLOW),
    ("transferHook", ["arbitrary program runs,", "extra CU + extra risk"], YELLOW),
    ("permanentDelegate", ["someone else can move", "this at any time"], YELLOW),
], width=290)
connect(t3, gates[1], "b", "t", color=PURPLE[0])

by = gy + tall + 55
b1 = card(L, by, "derive ATAs", ["source + destination"], GREY, width=230)
b2 = card(L + 290, by, "createIdempotent", ["if destination missing", "~0.002 SOL rent, shown"], BLUE, width=270)
b3 = card(L + 620, by, "transferChecked", ["decimals verified", "on chain"], GREEN, width=240)
b4 = card(L + 920, by, "preview -> send", [], YELLOW, width=210)
chain([b1, b2, b3, b4])

note(L, by + 120, "WHY transferChecked AND NOT transfer", [
    "transferChecked verifies decimals on chain, which turns a decimals mistake into a",
    "rejected transaction instead of a 1000x transfer.",
], color=GREEN, width=880)

# ═══ RIGHT COLUMN ═══════════════════════════════════════════════════
ry = section(R, 150, 5, "F3 — dApp Connect",
             "iOS has no Mobile Wallet Adapter. This is the deeplink equivalent.")

note(R, ry, "WHY NOT MWA", [
    "MWA's association step is built on Android intents plus a local WebSocket.",
    "There is no sanctioned iOS path. This scheme is Solfare's own until a dapp",
    "adopts it — a distribution problem, not a code problem. Say so plainly.",
], color=GREY, width=880)
ry += 120

steps = [
    ("1  CONNECT REQUEST", [
        "solfare://v1/connect",
        "?dapp_encryption_public_key=<x25519>",
        "&app_url=<https origin>  &redirect_link=",
    ], PURPLE),
    ("2  VALIDATE + DERIVE", [
        "reject unless app_url is https",
        "session_kp = PrivateKey.generate()",
        "shared = Box(mine, theirs)   pinenacl",
    ], GREEN),
    ("3  APPROVAL SHEET", [
        "show the ORIGIN HOST as identity,",
        "never the dapp's self-declared name",
    ], RED),
    ("4  SEALED RESPONSE", [
        "nonce = random 24 bytes",
        "payload = box.encrypt({public_key, session})",
    ], PURPLE),
    ("5  v1/signAndSendTransaction", [
        "decrypt · auth failure = silent drop",
        "VERIFY fee payer is our wallet",
        "VERIFY no unknown required signers",
    ], GREEN),
    ("6  PREVIEW + APPROVE", [
        "same TxPreviewSheet as every other path",
        "origin + balance deltas + risk flags",
    ], RED),
    ("7  ENCRYPTED RESULT", [
        "{ signature }  or  { errorCode: 4001 }",
    ], PURPLE),
]
prev = None
for title_, body_, col in steps:
    c = card(R, ry, title_, body_, col, width=560)
    if prev:
        connect(prev, c, "b", "t", gap=6)
    prev = c
    ry += c["height"] + 42

note(R + 620, ry - 640, "THREAT MODEL", [
    "phishing brand      -> origin host is the identity",
    "disguised payload   -> preview from simulation,",
    "                       not the dapp's description",
    "replay              -> single-use nonce, request id",
    "stale session       -> expiry + one-tap revoke list",
    "wallet drain        -> danger flags on approvals",
    "sign for other key  -> reject if fee payer isn't us",
    "silent signing      -> no auto-approve path. ever.",
], color=RED, width=560)

note(R + 620, ry - 330, "ALREADY IN THE TREE", [
    "pinenacl 0.6.0 arrives transitively via the",
    "solana package and gives Curve25519 +",
    "XSalsa20 + Poly1305 — the same construction",
    "the established iOS wallet schemes use.",
    "",
    "No new dependency. No custom crypto.",
], color=TEAL, width=560)

# ─── 6. Solana Pay ─────────────────────────────────────────────────
ry = section(R, ry + 40, 6, "F2 — Solana Pay",
             "SolanaPayRequest and SolanaTransactionRequest ship inside package:solana.")

q1 = card(R, ry, "QR SCAN", ["existing scanner screen"], GREY, width=250)
q2 = card(R + 300, ry, "PARSE solana: URL", ["tryParse both kinds"], GREY, width=280)
connect(q1, q2)

fy = ry + q2["height"] + 55
f1 = card(R, fy, "TRANSFER REQUEST", [
    "recipient · amount · spl-token",
    "build the instruction locally",
    "append reference keys (read-only)",
], BLUE, width=420)
f2 = card(R + 460, fy, "TRANSACTION REQUEST", [
    "GET link -> label + icon",
    "POST {account} -> base64 tx",
    "verify fee payer, then decode",
], YELLOW, width=420)
connect(q2, f1, "b", "t", color=BLUE[0])
connect(q2, f2, "b", "t", color=YELLOW[0])

py = fy + max(f1["height"], f2["height"]) + 55
p = card(R + 230, py, "TxPreviewSheet -> sendAndConfirm", [], YELLOW, width=460)
connect(f1, p, "b", "t")
connect(f2, p, "b", "t")

note(R, py + 110, "MERCHANT STRINGS ARE ATTACKER-CONTROLLED", [
    "label, message and icon come from the merchant. Render them as untrusted content;",
    "the origin host is the only trustworthy identity. reference keys stay read-only",
    "non-signer. https is enforced at parse and that check is not to be relaxed.",
], color=RED, width=880)

# ─── 7. Build order ────────────────────────────────────────────────
ry = section(R, py + 250, 7, "Build order",
             "Dependency-ordered. Each step ships on its own.")

order = [
    ("F1a", "decoder + models", "pure functions, unit-testable, no network", GREEN),
    ("F1b", "preview engine", "simulateTransaction -> balance deltas", GREEN),
    ("F1c", "risk engine", "deltas AND decoded instructions", GREEN),
    ("F1d", "TxPreviewSheet", "wired into the existing send flow first", GREEN),
    ("F4", "SPL + Token-2022", "smallest real feature once the spine exists", BLUE),
    ("F2", "Solana Pay", "transfer requests, then transaction requests", BLUE),
    ("F3", "dApp Connect", "largest; safest once F1 is proven in production", PURPLE),
]
prev = None
for tag, name, why in [(a, b, c) for a, b, c, _ in order]:
    col = dict((a, d) for a, b, c, d in order)[tag]
    c = card(R, ry, "%-5s %s" % (tag, name), [why], col, width=880, size=13)
    if prev:
        connect(prev, c, "b", "t", gap=4)
    prev = c
    ry += c["height"] + 28

scene = {
    "type": "excalidraw",
    "version": 2,
    "source": "https://excalidraw.com",
    "elements": elements,
    "appState": {"gridSize": None, "viewBackgroundColor": "#ffffff"},
    "files": {},
}

out = "docs/design/solfare-system-design.excalidraw"
with open(out, "w") as f:
    json.dump(scene, f, indent=2)
print("wrote %s  (%d elements)" % (out, len(elements)))
