# Telegram roles and WebApp hosts

## Canonical runtime

`0xda-market/telegram-bot` is the only active Telegram host. `client`, `broker`, and `admin` are roles and capability sets resolved from the authenticated core session; they are not separate bots, services, repositories or Telegram applications.

```text
Telegram user
  -> 0xda-market/telegram-bot
  -> signed Telegram host adapter
  -> 0xda-market/webapp-core
  -> role-driven workspace
  -> 0xda-market/core API
```

The archived `0xda-market/telegram-broker-bot` repository is legacy history only.

## Responsibility boundary

`telegram-bot` owns the Telegram Bot API and Mini App SDK, `initData` verification, signed BFF transport, Telegram presentation capabilities and role-to-workspace mapping.

`webapp-core` owns shared client catalog, checkout, broker and administrator interfaces plus host-independent state, validation and responsive behavior.

`core` owns durable users, roles, products, currencies, offers, inventory, prices and orders. Browser-local offer drafts are provisional and are not durable market offers.

## Current broker slice

A signed session with role `broker` or `admin` mounts the broker workspace after the shared catalog. Product choices come from the complete catalog; quote currencies come from the canonical core currency catalog. Drafts are isolated in browser storage by an HMAC-derived opaque subject and deployment environment.

Durable offer persistence requires an explicit core API contract and must replace this storage adapter without moving business authority into Telegram or the browser.
