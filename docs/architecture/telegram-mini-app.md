# Telegram Web App Adapter

This repository owns the Telegram-specific host for the shared `0xda-market/web-app` package.

```text
telegram-bot/webapp
  ├─ Telegram SDK host adapter
  ├─ signed initData transport
  ├─ Telegram browser shell
  └─ Telegram BFF routes

0xda-market/web-app
  └─ host-agnostic catalog and checkout UI

0xda-market/core
  └─ provider-agnostic engine and market contracts
```

The Telegram adapter owns:

- `Telegram.WebApp` initialization;
- locale and viewport extraction;
- Telegram theme and haptics;
- raw `initData` transmission;
- `/webapp/bootstrap`, `/webapp/quotes/*` and `/webapp/orders/*` transport;
- Telegram menu-button registration and deployment entry point.

The shared Web App does not import Telegram SDKs or know about Telegram endpoints. The adapter imports `mountMarketApp`, constructs `host` and `transport`, imports the shared core engine, and mounts the UI.

```text
Telegram host + Telegram transport
  -> mountMarketApp(...)
  -> shared Web App UI
  -> core engine
```

## Session validation

Every BFF request carries raw `Telegram.WebApp.initData` in `X-Telegram-Init-Data`. `TelegramWebAppAuth` rejects malformed or stale payloads and verifies the Telegram HMAC before market operations.

The browser never receives the Telegram bot token, `MARKET_API_TOKEN` or an internal market user UUID.

## Runtime module routes

The Telegram shell expects:

- shared Web App module: `/web-app/index.js`;
- core browser engine: `/webapp-core/index.js`;
- signed Telegram BFF: relative `/webapp/*` routes.

These may be overridden before `webapp/app.js` loads with `window.__ZERO_X_DA_MARKET__`.

## Activation order

1. merge and publish the host-agnostic `web-app` module;
2. merge this Telegram adapter;
3. expose `/web-app/index.js` through the development edge route;
4. deploy and verify the development bot runtime;
5. enable Telegram menu-button registration only after health checks pass.

Menu-button registration remains gated by `REGISTER_TELEGRAM_WEBAPP`.
