# The swap screen's height budget

The percentage row appears sliced in half by the keypad. Nothing is stacked on
top of anything — the row is being clipped, and a clip that lands inside a row
of buttons reads as an overlap.

## Where the space goes

Measured, not estimated. `SwapScreen` sits inside the homepage shell:

    Scaffold > SafeArea(bottom: false) > Column
      Expanded(Padding(vertical: 10, child: tab))
      BottomNavBar

On a 393x852 device with a 59pt status bar and a 34pt home indicator, that
leaves the swap screen **682pt**. The parts it has to fit, each measured by
rendering the widget:

| part                | height |
|---------------------|--------|
| header              | 48     |
| amount card (x2)    | 122    |
| flip divider        | 52     |
| percentage row      | 43     |
| keypad              | 248    |
| review button       | 48     |

With the spacers the screen asks for, that totals about **790pt** — roughly
110 more than it has. `SingleChildScrollView` does not complain about this the
way a `Column` would; it clips in silence, and the clip landed inside the
percentage row.

Two of those points are simply wasted. The pinned block pads its bottom by
`MediaQuery.of(context).padding.bottom + 2`, reserving 34pt for the home
indicator — but the nav bar underneath already pads for it, and the outer
`SafeArea` is `bottom: false`, so nothing removed the inset from the
MediaQuery on the way down. Verified rather than assumed: a probe of the real
nesting reports the inset arriving as 34 inside the swap screen.

## The design

Split the screen by what the parts are for, not by where they happen to sit.

**Input is pinned.** The two amount cards, the percentage row, the keypad and
the button are what the user is operating. The percentage row moves out of the
scrolling area and joins the keypad: 25/50/75/Max is an amount shortcut, the
same kind of thing as a key, and pinning it means it can never be the thing a
clip lands in.

**Information scrolls.** Rate, slippage tolerance, the quote error, and the
insufficient-balance banner sit above, and scroll when a quote makes them
appear. The button label already says `Insufficient SOL`, so the banner
explaining the fee reserve is not the only warning.

**The keypad gives back what it does not need.** Even with the wasted inset
recovered, a 248pt keypad plus a 48pt button plus two 122pt cards do not fit in
682. So the key height is computed from what is left after the cards, clamped
to a floor:

    keys = (available - cards - percentRow - button - gaps) / 4
    keyHeight = keys.clamp(44, 56)

44pt is the smallest comfortable target, and the keys are 76pt wide with an
opaque hit area, so the floor is a real floor and not a guess. On the 852pt
device this lands at ~48pt and everything fits with nothing clipped. On a 667pt
phone it bottoms out at 44 and the cards scroll — degrading by scrolling the
cards, which is legible, rather than by slicing a row of buttons, which is not.

## Why constants

The budget needs the cards' natural height before it can size the keys, and a
layout pass cannot ask a sibling how tall it wants to be. So the heights above
live as named constants in `SwapLayout`. Constants copied from a measurement
rot the moment a font or a padding changes, so `swap_layout_test` re-measures
and fails if one no longer matches. Measuring a copy of the widget is no guard
at all — a copy drifts silently — so the amount card moved out of the screen
into `AmountCard`, where the test measures the same widget the screen builds.

The cards are budgeted 8pt more than they need, because landing exactly on the
boundary means the first point of drift is a clipped edge. With the margin it
is a gap.

## What it comes out at

Rendering the screen under the shell's real constraints, on the 393x852
device: the scrolling half runs 118-418 and the buy card ends at 418, so
nothing is cut; the percentage row starts at 438, below the scroll and inside
the pinned band; the keys come out at ~46pt; and the button's bottom edge lands
on the last point the screen has. Before this, the same measurement had the
pinned half asking for 665pt of the 634 available.
