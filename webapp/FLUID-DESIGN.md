# 0xda-market Fluid Design Direction

## Concept

**0xda-market is a dark operational surface with fluid control instruments moving above it.**

The interface should not make every surface translucent. The visual system is built around a clear separation:

- **solid, stable surfaces** for information, forms, balances, prices, and operational state;
- **fluid surfaces** for navigation, selection, confirmation, and primary actions.

The result should feel futuristic and technical without copying iOS Liquid Glass or falling into generic glassmorphism.

---

## Core Principle

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

### Background

Use a near-black graphite background rather than absolute black.

The tone should be slightly cool and deep enough to separate application layers without visible gradients dominating the screen.

### Sections and cards

Cards and working sections should be matte and one level lighter than the background.

Avoid thick gray borders. Prefer:

- a subtle inner highlight;
- a soft downward shadow;
- restrained tonal separation;
- rounded geometry with consistent radii.

The intended hierarchy is:

1. application background;
2. stable content surfaces;
3. fluid interactive surfaces;
4. active accent lens.

---

## Fluid Material

The fluid material is the signature interaction layer of 0xda-market.

It should derive translucency, contrast, accent depth, and highlights from the active Telegram theme while preserving the project’s own character.

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

---

## Active Lens

The selected action should not simply become blue.

A distinct **accent lens** should move inside the fluid bar.

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

---

## Navigation

### Workspace bar

The bottom workspace navigation is the primary expression of the fluid design system.

It should:

- float above content;
- retain strong contrast in dark and light Telegram themes;
- use one moving active lens;
- avoid separate filled buttons for each tab;
- remain readable without relying only on color.

When the software keyboard is visible, the fixed workspace navigation must disappear or become non-interactive so only one fixed control plane remains above the keyboard.

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

Cards should feel dense, stable, and operational.

### Product card structure

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

This gives tactile feedback while preserving the technical character.

---

## Forms

### Input fields

Inputs should read as matte recesses inside stable surfaces.

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

### Validation

Do not flood invalid fields with red.

Prefer:

- a thin semantic edge;
- a short inline explanation;
- one restrained pulse;
- preserved field readability.

### Numeric fields

Numeric inputs must continue using native numeric keyboard contracts with correct `inputmode`, scale, minimum, and step behavior.

Visual styling must never weaken the semantic input contract.

---

## Buttons

### Primary actions

Primary actions may use the fluid material.

They should appear as deliberate operational commands, not decorative pills.

Examples:

- save changed prices;
- publish listing;
- create product;
- confirm purchase;
- accept order.

### Secondary actions

Secondary actions should remain matte or transparent with a subtle boundary.

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

## Administration Workspace

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

Inventory balances should be visually grouped because they represent one server-owned equation.

The interface must not imply that the browser calculates or owns those balances.

---

## Orders and Fulfillment

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

### Primary accent

Use an electric blue as the main interactive accent, but keep it concentrated inside the fluid material.

Do not use large flat blue surfaces across the interface.

### Semantic colors

- **Electric blue** — active navigation and primary action;
- **Cool green** — successful or completed state;
- **Amber** — waiting, reservation, or pending state;
- **Muted red** — error or destructive action;
- **Neutral graphite** — stable information surfaces.

Semantic colors must supplement labels and icons rather than replace them.

---

## Typography

Use a clear hierarchy with fewer bold elements.

### Recommended roles

- large section titles;
- medium card titles;
- compact operational labels;
- monospaced or tabular numerals where useful;
- subdued descriptions and metadata.

Avoid making every label bold. Excessive weight reduces hierarchy and makes the interface visually noisy.

Prices, quantities, revisions, and inventory balances should remain highly legible.

---

## Motion

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

The visual system must preserve:

- readable contrast in light and dark Telegram themes;
- visible focus states;
- minimum touch target sizes;
- semantic button and tab roles;
- `aria-selected` for active navigation;
- `aria-busy` and inert state during writes;
- text or icon reinforcement for semantic colors;
- opaque fallback when backdrop filtering is unavailable.

Fluid material is a progressive enhancement, not a dependency for usability.

---

## Design Boundaries

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

### Phase 1 — interaction layer

- workspace fluid bar;
- active lens;
- keyboard confirmation;
- primary fluid buttons;
- opaque and reduced-motion fallbacks.

### Phase 2 — stable surfaces

- background and card hierarchy;
- input fields;
- section spacing;
- typography;
- semantic states.

### Phase 3 — operational screens

- pricing rows;
- product editor;
- listing inventory cards;
- order lifecycle;
- compact administration metrics.

### Phase 4 — refinement

- motion tuning;
- theme tuning;
- contrast validation;
- landscape behavior;
- performance checks inside Telegram WebView.

---

## Design Statement

> **0xda-market is a dark operational surface with fluid control instruments moving above it.**

The interface should feel original, controlled, and technically precise: stable where information matters, fluid where intent becomes action.
