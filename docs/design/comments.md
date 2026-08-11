# Comments

The rule for this codebase, written down because it drifted twice.

## The rule

**A comment says what a thing is. Never why it is that way.**

The "why" — the bug it prevents, the alternative that was rejected, the
measurement behind a constant — goes in `docs/design/`. Git carries the
history. Neither belongs beside the code.

- `///` on the public surface. One sentence.
- `//` inside a body, only where the code cannot say it itself: a protocol
  fact, a byte layout, a platform quirk, a constant nobody could re-derive.
- Nothing else.

## What that rules out

| | |
|---|---|
| Archaeology | `// The old code reset the counter, so the limit was flat` |
| Narration | `// Dispatch event to BLoC — BLoC will update state` |
| Labels | `// Header`, `// Drag handle`, `// Content` |
| Restating the name | `/// Event to create a new wallet` above `CreateWalletEvent` |

A comment that repeats its declaration is worse than none: it is a second
thing to keep in sync, and it is the one that will be wrong.

## What earns its place

    // Layout: [compact-u16 signature count][count * 64 bytes][message].

    // resetOnError defaults to TRUE in flutter_secure_storage 10, whatever
    // its own doc comment claims, and the native side honours it by calling
    // deleteAll() on any storage error.

    // Dart ints are signed, so a u64 at or above 2^63 comes back negative.

None of these can be read off the code, and getting each one wrong costs
real money.

## Tests are the exception

A test comment may state the invariant the assertion pins down, because the
test name cannot carry it. It still may not narrate, and it still may not
recount what an earlier version of the test did wrong.

## The measurement

Taken against [gleec-wallet](https://github.com/GLEECBTC/gleec-wallet),
generated code excluded from both sides.

| | comment lines | of all lines | per file | longest block |
|---|---|---|---|---|
| solfare, before | 3,060 | 10.6% | 20.5 | 51 lines |
| solfare, after | 1,255 | 4.1% | 6.9 | 5 lines |
| gleec-wallet | 5,141 | 4.4% | 5.2 | 59 lines |

Density was never the real problem — the block size was. A quarter of the
comments ran four lines or more, which is a paragraph of prose per screenful
of code, and paragraphs are where the "why" hides.

To re-measure:

    python3 - <<'EOF'
    import os
    tot = cm = 0
    for d, _, fs in os.walk('lib'):
        for f in fs:
            if not f.endswith('.dart') or 'l10n' in d: continue
            for line in open(os.path.join(d, f)):
                tot += 1
                cm += line.strip().startswith('//')
    print(f'{cm} / {tot} = {100 * cm / tot:.1f}%')
    EOF
