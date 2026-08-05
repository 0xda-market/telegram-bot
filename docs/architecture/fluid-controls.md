# Fluid controls

The Telegram Mini App uses an adapter-owned fluid material for its fixed workspace navigation and mobile keyboard confirmation control.

This is not an imitation of a platform navigation bar. It is a 0xda-market surface built from the active Telegram theme with three layers:

1. a translucent theme-derived base;
2. directional highlights that suggest depth without a fixed light-mode or dark-mode palette;
3. an accent lens for the selected workspace action.

The implementation lives in `webapp/fluid-controls.css`. It uses `color-mix`, `backdrop-filter`, layered gradients and inset edges. Browsers without backdrop filtering receive an opaque theme-derived fallback. Reduced-motion preferences remove control transitions.

## Interaction contract

The workspace navigation remains role-driven and owned by `webapp-core`; this adapter changes presentation only. The selected tab is expressed through material depth, not a copied platform indicator.

When a text or numeric field owns focus, `webapp-core` exposes the host-provided keyboard confirmation control at the current `VisualViewport` edge. The fixed workspace navigation becomes hidden and non-interactive for that interval, so the confirmation action never overlaps a selected workspace tab. Activating confirmation only blurs the active field. It does not submit, save or invoke transport.

## Design constraints

- theme-derived rather than hard-coded light or dark glass;
- one clear interactive plane above the keyboard;
- no dependency on iOS-only APIs or visual assets;
- readable opaque fallback when blur is unavailable;
- no change to role authorization, workspace selection or POST behavior.
