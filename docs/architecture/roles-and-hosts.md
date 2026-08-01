# Telegram roles and Web App hosts

## Canonical runtime

`0xda-market/telegram-bot` is the only active Telegram host.

`client`, `broker`, and `admin` are roles and capability sets resolved from the authenticated core session. They are not separate bots, deployable services, repositories, Ruby namespaces, or Telegram applications.

```text
Telegram user
  -> 0xda-market/telegram-bot
  -> signed Telegram host adapter
  -> 0xda-market/web-app
  -> role-driven workspace
  -> 0xda-market/core
```

The archived `0xda-market/telegram-broker-bot` repository is legacy history only. It must not be used for new implementation, deployment, documentation, or operational decisions.

## Responsibility boundary

### `telegram-bot`

Owns:

- Telegram Bot API and Mini App SDK integration;
- `initData` verification and signed BFF transport;
- Telegram locale, viewport, theme and haptics;
- Telegram menu and Web App entry points;
- mapping the authenticated core role to Web App capabilities.

Does not own broker offers, products, prices, orders or role assignments.

### `web-app`

Owns shared role-driven interfaces:

- client catalog and checkout;
- broker offer workspace;
- administrator workspace;
- host-independent validation, responsive layout and localization.

It contains no Telegram SDK or bot token.

### `core`

Owns durable users, roles, products, offers, inventory, prices and orders. Browser-local offer drafts are explicitly provisional and are not durable market offers.

## Current broker slice

A signed session with role `broker` or `admin` mounts the broker workspace after the shared catalog. The workspace supports:

- selecting a catalog product;
- changing quantity;
- changing quoted amount;
- changing quote currency independently from locale;
- creating, editing and deleting local offer drafts.

The first development slice stores drafts in browser local storage under a versioned key. Durable offer persistence requires an explicit core API contract and must replace this storage adapter without moving business authority into Telegram or the browser.
