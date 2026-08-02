# Telegram WebApp adapter

This repository owns the Telegram-specific host for the shared [`0xda-market/webapp-core`](https://github.com/0xda-market/webapp-core) package.

```text
telegram-bot/webapp
  ├─ Telegram SDK host adapter
  ├─ signed initData transport
  ├─ Telegram browser shell
  └─ Telegram BFF routes

0xda-market/webapp-core
  ├─ host-agnostic catalog and checkout UI
  ├─ catalog and checkout engine
  └─ role-driven workspaces

0xda-market/core
  └─ provider-agnostic backend and market contracts
```

The Telegram adapter owns Telegram SDK initialization, locale, viewport, theme, haptics, raw `initData` transmission, BFF transport and deployment. `webapp-core` contains no Telegram SDK, bot token, endpoint or deployment entry point.

## Bootstrap contract

The bootstrap transport preserves the complete `{ data, meta }` document. `webapp-core` converts it into an explicit `{ catalog, session, currencies }` context. Quote, order and broker-listing transports unwrap their `data` resources. Broker listing writes always pass through verified Telegram authentication and the core API; no durable market state is stored in the browser.

Every BFF request carries raw `Telegram.WebApp.initData` in `X-Telegram-Init-Data`. The server validates the HMAC, age and verified Telegram user before market operations. The public session never exposes the internal market UUID or bot token.

## Entry-point contract

Every authenticated private-chat user receives a `web_app` launch action in the `/start` and `/status` account card. The action opens the adapter-owned `/webapp/` URL derived from `PUBLIC_URL`; the verified session then selects the client, broker or admin workspace.

This in-chat entry point is the baseline access path and does not depend on global Telegram menu-button registration. `REGISTER_TELEGRAM_WEBAPP=1` may still install the same URL as the global chat menu button, but that registration remains an optional deployment concern rather than a prerequisite for opening the Mini App.

## Role workspace contract

The Telegram host passes only the verified bootstrap context into the shared workspace package:

- `client` mounts the Market surface;
- `broker` mounts Market and Listings;
- `admin` mounts Market, Listings and the read-only Administration overview.

The host moves the broker workspace out of the market shell before mounting navigation so every section remains an independent surface. The navigation cannot grant capabilities: unavailable sections are filtered by the verified role inside `webapp-core`.

Administration is intentionally expanded one capability at a time: products and localizations, prices, users, orders, all listings, then manual fulfillment. Wallet and automated settlement remain outside this sequence.

## Immutable module dependency

`webapp/app.js` imports one `webapp-core` module from an exact Git commit revision. Relative imports resolve to the same immutable revision. Production does not load a mutable default-branch URL.

The pinned revision is updated only in a reviewed Telegram PR after the matching `webapp-core` checks are green. No separate `/web-app/*` UI module or `/webapp-core/*` engine module is required from `core`.
