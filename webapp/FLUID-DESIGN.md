# 0xda-market Fluid Design Direction

## Concept

**0xda-market is a dark operational surface with fluid control instruments moving above it.**

The interface should not make every surface translucent. The visual system is built around a clear separation:

- **solid, stable surfaces** for information, forms, balances, prices, and operational state;
- **fluid surfaces** for navigation, selection, confirmation, and primary actions.

The result should feel futuristic and technical without copying iOS Liquid Glass or falling into generic glassmorphism.

---

## Ownership

This document describes one application assembled from two repositories, and a rule is only actionable in the repository that owns the markup it applies to.

- **`Owner: adapter`** — this repository. Stylesheets, the Telegram shell, tokens, material, motion.
- **`Owner: webapp-core`** — the pinned module in `webapp/app.js`. Section structure, field order, row and card composition. These rules cannot land here; they require a reviewed change in [`0xda-market/webapp-core`](https://github.com/0xda-market/webapp-core) followed by a revision bump.
- **`Owner: shared`** — a rule both must honour, usually because it constrains a contract rather than a surface.

Every chapter below carries its owner. A chapter owned by `webapp-core` is a request against that repository, not a task for this one.

---

## Core Principle

`Owner: shared`

### Solid system, fluid control

Content must remain calm, dense, and readable.

The fluid material appears only where the user:

- navigates;
- selects;
- confirms;
- submits;
- changes an active state.

This gives the effect a functional meaning rather than turning it into decoration.

---

## Visual Foundation

`Owner: adapter`

### Base surface

**The base surface is brand-owned and always dark. Only the accent, the lens and the material highlights derive from the active Telegram theme.**

This is a deliberate trade: the application does not follow a user's light Telegram theme. The alternative — deriving surface tone from the theme — would make "dark operational surface" one of two skins and would require designing, measuring and maintaining a second palette. The fluid material also depends on layered translucency over a known dark base to stay predictable.

The background is near-black graphite rather than absolute black: slightly cool, deep enough to separate layers without visible gradients dominating the screen.

### Tokens

Tones, geometry, spacing, motion and targets are declared once in `webapp/design-tokens.css`. This document names tokens rather than describing them, so an implementation can be reviewed against it:

| Role | Token |
| --- | --- |
| application background | `--surface-base` |
| stable content surfaces | `--surface-raised` |
| dialogs and floating panels | `--surface-floating` |
| inputs and recesses | `--surface-recessed` |
| card and section separation | `--edge-hairline`, `--edge-highlight` |
| interactive boundary | `--edge-control` |
| text | `--text-primary`, `--text-secondary`, `--text-muted` |
| interactive accent | `--accent` (theme-derived) |
| geometry | `--radius-control`, `--radius-card`, `--radius-plane` |
| rhythm | `--space-1` … `--space-5` (4px base) |
| motion | `--motion-press`, `--motion-state`, `--motion-lens`, `--ease-viscous` |

### Sections and cards

Cards and working sections use `--surface-raised`, one step above the background.

Avoid thick gray borders. Prefer:

- a subtle inner highlight;
- a soft downward shadow;
- restrained tonal separation;
- rounded geometry with consistent radii.

This applies to separation, not to identification. Two near-black surfaces cannot reach 3:1 against each other at any tone, so an interactive control is identified by its boundary and uses the stronger `--edge-control`. Cards and sections, which are only separated, keep the quieter hairline.

The intended hierarchy is:

1. application background;
2. stable content surfaces;
3. fluid interactive surfaces;
4. active accent lens.

---

## Fluid Material

`Owner: adapter`

The fluid material is the signature interaction layer of 0xda-market.

It derives translucency, contrast, accent depth, and highlights from the active Telegram theme while preserving the project's own character.

### Intended use

Apply the material to:

- workspace navigation;
- the keyboard confirmation control;
- primary submit actions;
- segmented controls;
- filters;
- selected states;
- high-priority contextual actions.

### Avoid

Do not apply it to:

- every card;
- every input;
- static informational blocks;
- history lists;
- large content backgrounds;
- destructive actions by default.

Too much fluid material would flatten the hierarchy and make all controls compete for attention.

### Fallback ladder

Fluid material is a progressive enhancement, and the enhancement must fail in the right direction. Every material background is declared as three steps, in this order:

1. a plain opaque colour that is always valid;
2. a `color-mix()` translucency;
3. the layered blurred material, behind an `@supports` guard.

`color-mix()` is the fragile dependency, not `backdrop-filter`. A declaration built from an unsupported function is dropped whole, so a fallback that is itself written in `color-mix()` is not a fallback. The plain colour must come first, in every rule, so a fixed control plane can never render without a background.

---

## Active Lens

`Owner: adapter`

The selected action does not simply become blue.

A distinct **accent lens** moves inside the fluid bar.

### Behavior

During a section change, the lens should:

- stretch toward the destination;
- move with a controlled, viscous response;
- compress slightly on arrival;
- settle into the selected control;
- subtly distort the material behind it.

The motion should feel like a dense transparent polymer rather than an elastic iOS-style spring.

### Character

The motion language should be:

- technical;
- restrained;
- deliberate;
- slightly viscous;
- fast enough for operational use.

### Construction

There is exactly one lens. Tabs never carry an individual fill — a per-tab background is the "separate filled buttons" pattern this document rejects, and it cannot express travel.

The lens is a pseudo-element of the navigation container, positioned from the selected index. The tab count and the selected index are read from the markup with `:has()`, so the adapter needs neither a script nor a change to the navigation produced by `webapp-core`. The container uses `gap: 0` so each tab is exactly one lens wide and lens travel is an exact multiple of its own width.

---

## Navigation

`Owner: adapter`

### Workspace bar

The bottom workspace navigation is the primary expression of the fluid design system.

It should:

- float above content;
- retain strong contrast against its own opaque fallback;
- use one moving active lens;
- avoid separate filled buttons for each tab;
- remain readable without relying only on color.

When the software keyboard is visible, the fixed workspace navigation must disappear or become non-interactive so only one fixed control plane remains above the keyboard.

### Locale elasticity

`uk_UA` is a primary locale and its labels run considerably longer than English — `Адміністрування` against `Admin`.

Every control must stay legible at 1.4× the English string length. Tab labels never wrap: a wrapped label breaks the bar's fixed height and its lens geometry. Where a label cannot fit, the fallback is an icon plus an accessible name, not a truncated word.

Tabs carry icons for this reason as well as the accessibility one: color alone must never distinguish the selected section. Below 430px the label becomes visually hidden rather than truncated, so the accessible name survives at full length.

Label overflow belongs to the stylesheet that owns the tab's icon and label elements. A tab is a grid container with no text of its own, so text handling declared on the tab itself is inert.

### Keyboard confirmation

The confirmation control above the keyboard should use the same material family as the workspace bar.

It is a temporary accessory, not a form submission action.

Its only responsibility is to:

- remove focus;
- dismiss the software keyboard;
- preserve the current input value;
- avoid starting any transport operation.

---

## Cards

`Owner: adapter`

Cards should feel dense, stable, and operational.

### Product card structure

`Owner: webapp-core`

A product card may contain:

1. category or status;
2. product name;
3. current client price;
4. availability or liquidity state.

### Interaction

On press, the card should not bounce dramatically.

Instead:

- the surface moves slightly inward;
- the shadow compresses;
- a short highlight travels along the edge;
- the card returns without a pronounced spring.

Press feedback uses `--motion-press` and `--ease-viscous`. This gives tactile feedback while preserving the technical character.

---

## Forms

`Owner: adapter`

### Input fields

Inputs read as matte recesses (`--surface-recessed`) inside stable surfaces.

Default state:

- low-contrast boundary;
- minimal visual noise;
- clear label hierarchy;
- strong numeric legibility.

Focused state:

- a thin fluid outline;
- a controlled accent concentration near the active field;
- no large glow;
- no layout shift.

A focused field also receives the standard focus ring when reached by keyboard. The accent boundary is decoration; the ring is the accessibility contract and is never suppressed.

### Validation

Do not flood invalid fields with red.

Prefer:

- a thin semantic edge;
- a short inline explanation;
- one restrained pulse;
- preserved field readability.

### Numeric fields

`Owner: shared`

Numeric inputs must continue using native numeric keyboard contracts with correct `inputmode`, scale, minimum, and step behavior.

Visual styling must never weaken the semantic input contract.

---

## Buttons

`Owner: adapter`

### Primary actions

Primary actions may use the fluid material or the flat accent.

They should appear as deliberate operational commands, not decorative pills.

Examples:

- save changed prices;
- publish listing;
- create product;
- confirm purchase;
- accept order.

### Secondary actions

Secondary actions remain matte with a hairline boundary. Catalog paging and locale chips are secondary: they navigate, they do not commit, and they must not read as primary commands.

### Destructive actions

Destructive actions should not use the primary fluid accent.

Use a restrained semantic treatment that is visually separate from ordinary confirmation.

### Loading state

A pending POST request should:

- make the owning section inert;
- expose `aria-busy`;
- prevent repeated submission;
- preserve the section geometry;
- show a visible but restrained loading indicator.

---

## States

`Owner: adapter` for presentation, `Owner: webapp-core` for the copy and the emitted state

An operational surface spends a large share of its life not showing a populated, healthy screen. Each surface defines five states, and none of them may collapse the section's geometry.

| State | Meaning | Treatment |
| --- | --- | --- |
| empty | the surface is legitimately empty — a new broker with no listings | one line of `--text-secondary` copy plus the action that resolves it |
| zero results | a filter or search excluded everything | copy names the filter, offers to clear it; never the same as empty |
| pending | a write is in flight | inert section, `aria-busy`, restrained indicator, unchanged geometry |
| stale | the server moved under the operator — most often a price revision | first-class state with a semantic edge and an explicit reload action, not an error |
| error | the operation failed | `--semantic-danger` edge, inline explanation, the failed action still visible |

Stale is the state most easily mistaken for an error. It is not one: the operator's view is simply older than the ledger, and the interface must say so without discarding their edits.

---

## Administration Workspace

`Owner: webapp-core`

The administration workspace should prioritize recurring operations over broad overview content.

Large informational cards should not dominate the screen.

### Recommended hierarchy

1. prices;
2. products;
3. product creation;
4. localizations;
5. less frequent operational capabilities.

### Overview metrics

Replace large overview cards with:

- compact metrics;
- a horizontal rail;
- concise status summaries;
- direct links into the relevant working section.

The overview should orient the administrator, not delay access to work.

---

## Prices

`Owner: webapp-core`

The pricing surface should make state changes immediately legible.

Each price row should clearly show:

- product name;
- current price;
- previous price;
- edited value;
- changed or unchanged state.

Changed rows may receive a subtle accent treatment.

The save action should remain singular and explicit:

- submit only changed values;
- preserve the proposal revision;
- display the pending state at section level;
- show the authoritative result after completion.

---

## Products

`Owner: webapp-core`

The selected product should become the main working context.

Recommended flow:

1. compact product selector;
2. selected-product summary;
3. locale-neutral fields;
4. product save action;
5. independent localization surface.

Do not visually merge product state, pricing, and localization into one form. Their contracts are independent and should remain visually distinct.

---

## Listings

`Owner: webapp-core`

A broker listing should communicate supply state in one compact operational card.

Recommended content:

- product;
- total quantity;
- available quantity;
- reserved quantity;
- sold quantity;
- supply price;
- listing status;
- edit and withdraw actions.

Inventory balances are visually grouped because they represent one server-owned equation.

The interface must not imply that the browser calculates or owns those balances.

---

## Orders and Fulfillment

`Owner: webapp-core`

Order state is better represented as a lifecycle than as a flat list of buttons.

Recommended states:

1. requested;
2. accepted;
3. payment pending or confirmed;
4. fulfillment in progress;
5. completed or failed.

Use a compact timeline or connected state rail.

Actions should appear only when the server contract permits the next transition.

---

## Color System

`Owner: adapter`

### Primary accent

`--accent` is an electric blue, kept concentrated inside the fluid material and the lens.

Do not use large flat blue surfaces across the interface.

### Semantic colors

- `--accent` — active navigation and primary action;
- `--semantic-success` — successful or completed state;
- `--semantic-pending` — waiting, reservation, or pending state;
- `--semantic-danger` — error or destructive action;
- `--surface-raised` — stable information surfaces.

Semantic colors must supplement labels and icons rather than replace them.

### Daypart

The interface follows the user's local hour, but only through material intensity and accent temperature. Three discrete states — `day`, `twilight`, `night` — modulate exactly four tokens:

| Token | day | twilight | night |
| --- | --- | --- | --- |
| `--edge-highlight` | 0.14 | 0.11 | 0.09 |
| `--edge-shadow` | 0.42 | 0.46 | 0.52 |
| `--accent-glow` | 42% | 34% | 26% |
| `--accent` | source | 94% source, 6% warm | 88% source, 12% warm |

Surfaces, text tones, `--edge-control`, focus and targets are identical in all three. The hour may change how the material reads; it may never change whether a price is legible. Accent contrast against `--surface-raised` is measured at every state (4.8:1, 4.9:1, 5.0:1).

Three constraints make this safe rather than decorative:

- **Local time decides glare, not luminance.** The hour is a poor proxy for ambient light — the platform's own auto-night knows more — so it is not allowed to decide surface tone. It is a fine proxy for how much glare is welcome.
- **Discrete, not a ramp.** A discrete state can be pinned, screenshotted and asserted. A continuous ramp would make a reported defect depend on the hour it was reported.
- **Pinnable.** A runtime override fixes the daypart, so a defect stays reproducible.

`day` is the base state, so a shell whose script never runs renders as though the daypart did not exist.

---

## Typography

`Owner: adapter`

Use a clear hierarchy with fewer bold elements.

### Recommended roles

- large section titles;
- medium card titles;
- compact operational labels;
- subdued descriptions and metadata.

Avoid making every label bold. Excessive weight reduces hierarchy and makes the interface visually noisy.

### Numerals

Prices, quantities, revisions and inventory balances carry `font-variant-numeric: tabular-nums`. Operational figures are read in columns and compared against each other; proportional digits make a changed price harder to spot than an unchanged one.

---

## Motion

`Owner: adapter`

Motion should explain state, not decorate idle screens.

### Allowed motion

- active-lens travel;
- short press compression;
- loading rotation;
- focused-field contour;
- section transition;
- state change confirmation.

### Motion constraints

- no continuous ambient animation;
- no large spring overshoot;
- no long blur transitions;
- no motion that delays an operation;
- respect `prefers-reduced-motion`.

---

## Accessibility

`Owner: shared`

The requirements below are numeric so an implementation can be checked rather than asserted.

| Requirement | Target |
| --- | --- |
| text contrast | 4.5:1, measured against the opaque fallback surface |
| interactive boundary (`--edge-control`) and focus ring | 3:1 |
| card and section separation (`--edge-hairline`) | decorative; identification comes from the control it wraps, never from this edge |
| touch targets | `--target-min` (44×44) for every interactive control |
| focus | `:focus-visible` ring using `--focus-ring`, never dependent on the fluid material |
| navigation semantics | `aria-selected` on tabs, semantic button and tab roles |
| write state | `aria-busy` and inert section during writes |
| semantic colour | always reinforced by text or an icon |
| material | opaque fallback whenever `color-mix()` or backdrop filtering is unavailable |

Contrast for text over translucent material is measured against the opaque fallback, because that is the only defined backdrop — anything scrolled behind the bar is not.

Fluid material is a progressive enhancement, not a dependency for usability.

---

## Shell

`Owner: adapter`

The application runs inside a Telegram WebView, not a browser tab.

Full-height surfaces use the host viewport height with a dynamic-unit fallback (`var(--tg-viewport-stable-height, 100dvh)`). `100vh` ignores the collapsed header and the on-screen keyboard, which is precisely the interval when the keyboard confirmation control has to be positioned correctly.

Layout and material are separated by file: `styles.css` owns position, size and typography for the fluid controls; `fluid-controls.css` owns their background, border, shadow, filter and lens. No selector declares the same property in both, which keeps the result independent of stylesheet order.

---

## Design Boundaries

`Owner: shared`

The visual system must not change application authority.

The browser remains responsible for presentation and interaction only.

The following remain server-owned:

- product availability;
- client pricing;
- broker allocation;
- inventory balances;
- quote expiration;
- payment state;
- order ownership;
- fulfillment state;
- optimistic concurrency;
- access control.

The design may clarify these contracts but must not simulate or infer them locally.

---

## Implementation Order

Each slice lands and reverts on its own. Slices 1–5 are adapter-only; slice 6 is the only one that requires the other repository.

1. **Tokens and safety** — token layer, fallback ladder, focus ring, host viewport units, layout/material file split. *Done.*
2. **Base surface** — brand-owned dark surfaces, `color-scheme: dark`, three-step elevation. *Done.*
3. **Active lens** — one travelling lens, tabs lose their individual fill, locale-safe tab labels. *Done.*
4. **Stable surfaces** — inputs, press feedback, secondary-action treatment, tabular numerals, 44px targets. *Done.*
5. **Daypart** — discrete local-hour states modulating material intensity and accent temperature only. *Done.*
6. **States** — empty, zero-results, stale and error treatments applied to market and prices.
7. **Operational screens** — price rows, product editor, listing inventory cards, order lifecycle, compact administration metrics. Gated on a `webapp-core` revision bump.
8. **Refinement** — motion tuning, contrast validation, landscape behavior, performance checks inside the Telegram WebView.

---

## Design Statement

> **0xda-market is a dark operational surface with fluid control instruments moving above it.**

The interface should feel original, controlled, and technically precise: stable where information matters, fluid where intent becomes action.
