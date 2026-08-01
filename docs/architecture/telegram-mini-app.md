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

The bootstrap transport preserves the complete `{ data, meta }` document. `webapp-core` converts it into an explicit `{ catalog, session, currencies }` context. Quote and order transports unwrap only their single `data` resource.

Every BFF request carries raw `Telegram.WebApp.initData` in `X-Telegram-Init-Data`. The server validates the HMAC, age and verified Telegram user before market operations. The public session exposes an opaque subject for local-draft isolation; it never exposes the internal market UUID or bot token.

## Immutable module dependency

`webapp/app.js` imports one `webapp-core` module from an exact Git commit revision. Relative imports resolve to the same immutable revision. Production does not load a mutable default-branch URL.

The pinned revision is updated only in a reviewed Telegram PR after the matching `webapp-core` checks are green. No separate `/web-app/*` UI module or `/webapp-core/*` engine module is required from `core`.
