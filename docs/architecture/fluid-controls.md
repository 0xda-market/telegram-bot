# Fluid controls

The Telegram Mini App uses an adapter-owned fluid material for its fixed workspace navigation and mobile keyboard confirmation control.

This is not an imitation of a platform navigation bar. It is a 0xda-market surface with three layers:

1. a translucent base built from the brand-owned dark surface;
2. directional highlights that suggest depth;
3. one accent lens that travels to the selected workspace action.

## Surface authority

The base surface is brand-owned and always dark; only the accent, the lens and the material highlights derive from the active Telegram theme. The application therefore does not follow a user's light Telegram theme. This keeps the layered translucency predictable over a known backdrop and removes the need to maintain and verify a second palette. Tones, geometry, spacing, motion and accessibility targets are declared once in `webapp/design-tokens.css`.

## Implementation

`webapp/styles.css` owns position, size and typography for both controls; `webapp/fluid-controls.css` owns their background, border, shadow, filter and lens. No selector declares the same property in both files, so the result does not depend on stylesheet order.

Material backgrounds are declared as a three-step ladder: a plain opaque colour, then a `color-mix()` translucency, then the layered blurred material behind an `@supports` guard. The fragile dependency is `color-mix()` rather than `backdrop-filter` — an unsupported function invalidates the whole declaration, so the opaque colour is always declared first and a fixed control plane can never render without a background. Reduced-motion preferences remove control transitions.

The active lens is a pseudo-element of the navigation container. Tab count and selected index are read from the markup with `:has()`, and the container uses `gap: 0` so lens travel is an exact multiple of the lens width. The adapter needs no script and no change to the navigation markup produced by `webapp-core`.

## Interaction contract

The workspace navigation remains role-driven and owned by `webapp-core`; this adapter changes presentation only. The selected tab is expressed by the travelling lens, not by a per-tab fill and not by a copied platform indicator.

When a text or numeric field owns focus, `webapp-core` exposes the host-provided keyboard confirmation control at the current `VisualViewport` edge. The fixed workspace navigation becomes hidden and non-interactive for that interval, so the confirmation action never overlaps a selected workspace tab. Activating confirmation only blurs the active field. It does not submit, save or invoke transport.

## Design constraints

- brand-owned dark base with a theme-derived accent, not a per-theme palette;
- one clear interactive plane above the keyboard;
- no dependency on iOS-only APIs or visual assets;
- readable opaque fallback when blur or `color-mix()` is unavailable;
- measurable targets: 44px controls, 4.5:1 text contrast, a `:focus-visible` ring independent of the material;
- no change to role authorization, workspace selection or POST behavior.
