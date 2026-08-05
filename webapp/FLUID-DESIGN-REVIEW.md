# Fluid Design Direction — review and proposals

A review of `webapp/FLUID-DESIGN.md` against the shipped adapter
(`webapp/*.css`, `webapp/index.html`, `webapp/app.js`) and the architecture
contracts in `docs/architecture/`.

The direction is sound. This document records where it is not yet actionable,
where it contradicts an existing contract, and where the implementation has
already drifted from it.

---

## What the direction gets right

- **Fluid material is scoped by function, not by surface.** Restricting the
  material to navigation, selection and confirmation is the decision that keeps
  the system from becoming generic glassmorphism, and it is stated before any
  visual detail.
- **The authority boundary is explicit.** "Design Boundaries" restates that
  availability, pricing, balances and payment state are server-owned. A visual
  document that repeats the trust model prevents a class of design ideas —
  local recalculation, optimistic balance rendering — from ever being drawn.
- **Motion is defined by prohibition.** No ambient animation, no overshoot, no
  motion that delays an operation. That is more useful than a curve library.
- **The keyboard accessory is defined by what it must not do.** "Remove focus,
  dismiss the keyboard, preserve the value, start no transport" is a contract,
  not a style note, and it matches `docs/architecture/fluid-controls.md`.

---

## Findings

### F1 — The document does not say which repository owns each rule

This is the largest gap. `docs/architecture/telegram-mini-app.md` establishes
that markup for the market, listings and administration surfaces is produced by
the pinned `webapp-core` module; this repository owns the shell, the adapters
and the stylesheets.

Most chapters of the direction are therefore not implementable here:

| Chapter | Requires |
| --- | --- |
| Cards, Forms, Buttons, Color, Typography, Motion | adapter CSS — implementable here |
| Active Lens, Navigation | adapter CSS, but depends on tab markup produced by core |
| Prices (row structure), Products (flow order), Listings (card content), Orders (lifecycle rail) | `webapp-core` markup — **not implementable here** |
| Administration Workspace (hierarchy, metric rail) | `webapp-core` structure — **not implementable here** |

Read as-is, the document reads like a backlog for this repository. Roughly half
of it is a change request against another repository at a pinned revision.

**Proposal P1** — mark every rule with its owner. A one-line marker per chapter
is enough: `Owner: adapter` / `Owner: webapp-core` / `Owner: shared contract`.
Rules owned by core additionally need a target revision, because they cannot
land until the pin in `webapp/app.js` moves.

### F2 — "Dark operational surface" contradicts the theme-derived contract

The design statement opens with a near-black graphite background and repeats it
in "Visual Foundation". Two other sources say the opposite:

- `docs/architecture/fluid-controls.md`: "theme-derived rather than hard-coded
  light or dark glass".
- The implementation: every fallback is light — `styles.css:4`
  (`#f3f4f6`), `styles.css:124` (`#fff`), `bootstrap.css:20`.

The document itself carries the contradiction: "Navigation" requires strong
contrast "in dark and light Telegram themes", while "Visual Foundation"
prescribes a single dark background. Under a light Telegram theme the current
build is a light application, which is a direct violation of its own design
statement.

This must be decided, not blended. The two coherent answers:

**A. Brand-owned base, theme-derived accent.** The application is always the
dark graphite surface. `--tg-theme-button-color` still drives the accent and
lens so the app feels native to the user's Telegram, but background and card
tones stop being theme-derived. Matches the design statement; requires setting
`color-scheme: dark` and abandoning the light fallbacks.

**B. Theme-derived base.** The graphite surface is the dark-theme expression of
the system, and the document must describe the light expression with equal
precision. Matches today's code and the architecture doc; requires rewriting
the design statement, because "dark operational surface" would then be one of
two skins.

**Proposal P2** — adopt **A**, and say so in one sentence at the top of "Visual
Foundation": *the base surface is brand-owned and always dark; only accent,
lens and highlight derive from the active Telegram theme.* It is the only
reading under which the design statement is literally true, it removes the need
to design and verify a second palette, and it keeps the fluid material — which
depends on layered translucency over a dark base — behaving predictably. The
cost is honest and should be recorded: the app will not follow a user's light
Telegram theme.

### F3 — No rule in the document is measurable

The direction is written entirely in adjectives: "one level lighter", "subtle
inner highlight", "consistent radii", "slightly viscous", "fast enough",
"restrained". Nothing can be reviewed against it — two implementations that
look nothing alike both conform.

The existing test (`test/webapp_adapter_contract_test.rb`) shows the
consequence: it can only assert that certain selector strings exist in the
stylesheet, because there is no numeric target to assert.

**Proposal P3** — add a token layer and make the prose reference token names.
`webapp/design-tokens.css`, imported first:

```css
:root {
  /* elevation ladder — F2 option A */
  --surface-base:      #0d0f13;   /* application background */
  --surface-raised:    #14171d;   /* cards, working sections */
  --surface-recessed:  #0a0c10;   /* inputs */
  --edge-hairline:     rgb(255 255 255 / 0.08);
  --edge-highlight:    rgb(255 255 255 / 0.14);

  /* geometry */
  --radius-control: 12px;
  --radius-card:    16px;
  --radius-plane:   20px;

  /* spacing — 4px base */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px;
  --space-4: 16px; --space-5: 24px;

  /* motion */
  --motion-press:      110ms;
  --motion-state:      180ms;
  --motion-lens:       260ms;
  --ease-viscous:      cubic-bezier(0.32, 0.72, 0.16, 1);

  /* targets */
  --target-min: 44px;
}
```

Then the prose changes from "cards one level lighter" to "cards use
`--surface-raised`", and a reviewer can check conformance by reading a diff.

### F4 — The signature feature is specified but not built

"Active Lens" is the centrepiece: one lens that stretches toward the
destination, compresses on arrival and distorts the material behind it.

`fluid-controls.css:65-79` implements something else — a per-tab background
applied to `[aria-selected="true"]`. There is no lens, no travel, and no
transition on any property that would move between tabs. This is close to what
the same document forbids two sections later: "avoid separate filled buttons
for each tab".

The gap is understandable — a moving lens normally needs a JS-positioned
element inside core-owned markup. It does not have to.

**Proposal P4** — implement the lens in adapter CSS with no core markup change
and no JavaScript, using the container as the positioning context and
`:has()` to read the selected index. With 2–3 tabs (the roles are client,
broker, admin) the cases are enumerable:

```css
.workspace-navigation { position: relative; --lens-count: 3; --lens-index: 0; }

.workspace-navigation::after {
  content: "";
  position: absolute;
  z-index: 0;
  top: var(--space-1);
  bottom: var(--space-1);
  left: var(--space-1);
  width: calc((100% - var(--space-2)) / var(--lens-count));
  border-radius: var(--radius-control);
  transform: translateX(calc(var(--lens-index) * 100%));
  transition:
    transform var(--motion-lens) var(--ease-viscous),
    scale     var(--motion-lens) var(--ease-viscous);
  background: /* accent lens material */;
}

.workspace-navigation:has(.workspace-tab:nth-child(2)[aria-selected="true"]) { --lens-index: 1; }
.workspace-navigation:has(.workspace-tab:nth-child(3)[aria-selected="true"]) { --lens-index: 2; }
.workspace-navigation:has(.workspace-tab:nth-child(3)):not(:has(.workspace-tab:nth-child(4))) { --lens-count: 3; }
.workspace-navigation:has(.workspace-tab:nth-child(2)):not(:has(.workspace-tab:nth-child(3))) { --lens-count: 2; }

/* viscous arrival: stretch along travel, compress on settle */
.workspace-navigation:active::after { scale: 1.04 0.96; }

@media (prefers-reduced-motion: reduce) {
  .workspace-navigation::after { transition: none; }
}
```

The selected tab then keeps only its `color` change and drops its background,
which is what the document actually asks for. This also makes the "no separate
filled buttons" rule enforceable in a test.

### F5 — The document describes only the successful state

Every chapter describes populated, healthy screens. Nothing describes what an
operational surface looks like when there is nothing to show or the transport
failed — which, for a market shell, is a large share of real sessions:

- catalog empty, or filtered to zero results;
- listings empty for a new broker;
- price proposal stale (revision moved under the operator);
- transport failed after the shell already mounted;
- data present but known to be old.

The shell already has vocabulary for this — `#status[data-error]`,
`.admin-products-status`, the bootstrap failure copy in `app.js:91-101` — but
it is styled as one grey line of text everywhere, and the direction never
mentions it.

**Proposal P5** — add a **States** chapter defining, per surface: empty,
zero-results, error, stale and pending. Two design rules worth fixing there:
loading never collapses a section's geometry (already implied by "preserve the
section geometry"), and a stale price revision is a first-class visual state,
not an error toast — it is the one state where the server disagrees with what
the operator is looking at.

### F6 — Locale elasticity is not addressed

`docs/architecture/telegram-mini-app.md` makes `uk_UA` a primary locale.
Ukrainian interface strings run considerably longer than English:
"Адміністрування" against "Admin", "Пропозиції" against "Listings".

The navigation is `grid-auto-columns: 1fr` (`styles.css:250`) with a 12px bold
label and no text handling anywhere in the adapter — no `text-overflow`, no
minimum, no wrap rule. Three equal columns on a narrow device with the longest
Ukrainian labels will wrap or clip, and the document's "remain readable without
relying only on color" is then violated by the layout, not by the palette.

**Proposal P6** — state a locale-elasticity rule: every control must remain
legible at 1.4× the English string length; tab labels never wrap; where the
label cannot fit, an icon plus accessible name is the fallback, not a
truncated word. This also settles a question the document leaves open — whether
tabs have icons at all. They should, precisely because color alone must not
carry meaning.

### F7 — The accessibility chapter asserts properties nothing enforces

The chapter lists correct requirements, but four of them are unmet in the
shipped adapter:

- **Visible focus states** — there is no `:focus-visible` rule anywhere in
  `webapp/`. On the fluid bar, whose tabs have `background: transparent` and a
  color-only selected state, focus is currently invisible.
- **Minimum touch targets** — no minimum is given, and two controls are below
  the common 44px: `.dialog-close` at 34×34 (`styles.css:155`) and
  `.admin-localization-list button` at 34px (`admin-products.css:78`).
- **Readable contrast** — no ratio is named, so no build step or review can
  check it. The tab rest color is `--tg-theme-text-color` mixed to 66% toward
  the hint color, over a translucent blurred background; that is contrast that
  varies with whatever is scrolled underneath.
- **Tabular numerals** — "Typography" recommends them for prices, quantities
  and balances; `font-variant-numeric` appears nowhere.

**Proposal P7** — make the chapter numeric: 44×44 minimum target, 4.5:1 for
text and 3:1 for control boundaries and focus rings, a focus token
(`--focus-ring`) that is a solid two-pixel outline with offset and never
depends on the fluid material, and `font-variant-numeric: tabular-nums` on
every money, quantity and revision field. Contrast for text over translucent
material is measured against the opaque fallback, which is the only defined
backdrop.

### F8 — The fallback ladder covers the wrong feature

"Accessibility" requires an opaque fallback when backdrop filtering is
unavailable, and `fluid-controls.css:107-112` provides it. But the fragile
dependency is `color-mix()`, not `backdrop-filter`.

Every background, border and shadow on the fluid bar is built from
`color-mix()` — including the `@supports not (backdrop-filter)` fallback
itself. On a WebView without `color-mix()`, each declaration is invalid and
dropped; the rule in `styles.css:255` is also `color-mix()`, so it is dropped
too. The result is not a degraded bar — it is a fixed navigation plane with no
background at all, with text over scrolling content.

**Proposal P8** — define a three-step ladder in the document and implement it
declaration-first: a plain opaque hex background, then the `color-mix()`
version, then the blurred version behind `@supports`. The first declaration
survives when the later ones are dropped, which is the whole mechanism.

```css
.workspace-navigation {
  background: #14171d;                                  /* always valid */
  background: color-mix(in srgb, var(--surface-raised) 72%, transparent);
}
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .workspace-navigation { background: /* layered fluid material */; }
}
```

### F9 — Viewport units are wrong for a Telegram WebView

Not in the document, but it belongs in "Phase 4 — landscape behavior and
WebView performance": `100vh` is used in three places (`styles.css:9`,
`styles.css:71`, `bootstrap.css:17`). In a Telegram WebView `100vh` ignores the
collapsed header and the on-screen keyboard, which is exactly the interval when
the keyboard confirmation control matters.

**Proposal P9** — prefer the host viewport variable with a dynamic-unit
fallback, and record it in the document as a shell rule:

```css
min-height: 100dvh;
min-height: var(--tg-viewport-stable-height, 100dvh);
```

### F10 — Two stylesheets own the same selectors

`.workspace-navigation`, `.workspace-tab`, `.keyboard-confirm` and the
`body:has(.keyboard-confirm:not([hidden]))` rule are each declared in both
`styles.css` and `fluid-controls.css`. The effective result depends only on
link order in `index.html:9-10`, and the pairs disagree: border `0` against
`1px`, `min-height: 38px` against `46px`, `border-radius: 11px` against `16px`.
The 38px value would be a sub-target control if the load order ever changed.

**Proposal P10** — one selector, one owner. `styles.css` keeps layout and
position for these controls; `fluid-controls.css` keeps material only
(background, border, shadow, filter). Under that split a selector legitimately
appears in both files, so the enforceable assertion is at property level: no
selector may declare the same property in both stylesheets. That makes the
result independent of link order, and it is a more durable check than the
current selector-string assertions.

### F11 — The implementation phases are not shippable slices

The four phases are grouped by kind of work — interaction layer, stable
surfaces, screens, refinement. Phase 2 is "background and card hierarchy,
inputs, spacing, typography, semantic states", which is a full visual rewrite
of the application in one step, and it cannot be reviewed incrementally or
reverted in part.

**Proposal P11** — re-cut into slices that each land alone, in this order:

1. tokens + fallback ladder + focus ring (no visible change beyond focus);
2. base surface decision from F2 (`color-scheme`, three surface tones);
3. active lens (F4), tabs lose their individual fill;
4. inputs, press feedback, tabular numerals;
5. states chapter (F5) applied to market and prices;
6. core-owned chapters, gated on a `webapp-core` revision bump.

Slices 1–5 are adapter-only and independently revertible. Slice 6 is the only
one that requires the other repository.

---

## Implementation drift table

Where the document and the adapter disagreed when this review was written. Every
row is now closed; the "Code" column records the state that prompted the
proposal, not the current one.

| Rule | Document | Code |
| --- | --- | --- |
| Base surface | near-black graphite | light fallbacks (`styles.css:4,124`) |
| Active selection | one moving lens | per-tab background (`fluid-controls.css:65`) |
| Card press | inward move, shadow compression, edge highlight | `scale(0.985)`, no transition (`styles.css:127`) |
| Secondary actions | matte, subtle boundary | filled accent pager buttons (`styles.css:141-148`) |
| Focus states | visible | absent |
| Numerals | tabular where useful | default figures |
| Touch targets | minimum enforced | 34px dialog close and locale chips |
| Fallback | opaque when blur unavailable | present, but itself `color-mix()`-dependent |

---

## Summary of proposals

| # | Proposal | Owner | Status |
| --- | --- | --- | --- |
| P1 | Mark every rule with its owning repository | doc | applied |
| P2 | Decide the base surface: brand-owned dark, theme-derived accent | doc + adapter | applied |
| P3 | Token layer; prose references tokens, not adjectives | adapter | applied |
| P4 | Build the active lens (CSS-only, no core change) | adapter | applied |
| P5 | Add a States chapter (empty, error, stale, pending) | doc | chapter written; treatments pending |
| P6 | Locale-elasticity rule; icons alongside tab labels | doc + core | rule written, labels made wrap-safe; icons need core |
| P7 | Numeric accessibility targets and a focus token | doc + adapter | applied |
| P8 | Three-step fallback ladder, declaration-first | adapter | applied |
| P9 | Host viewport units instead of `100vh` | adapter | applied |
| P10 | One selector, one stylesheet; contract test | adapter | applied |
| P11 | Re-cut phases into independently revertible slices | doc | applied |

P2 was the decision that unblocked the rest: it is recorded in
`FLUID-DESIGN.md` and in `docs/architecture/fluid-controls.md`, which
previously required the opposite, and every token value in P3 follows from it.

What remains is the work that cannot land in this repository. The chapters
marked `Owner: webapp-core` — price row composition, product editor flow,
listing inventory cards, the order lifecycle rail and the compact
administration metrics — need a reviewed change in `webapp-core` and a revision
bump in `webapp/app.js`. Tab icons (P6) are in that set: the adapter can keep a
label from wrapping, but it cannot add an icon to markup it does not own.
