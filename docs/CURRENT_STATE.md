# Current project state

This document summarizes the Telegram adapter contract implemented as of 2026-08-07.

## Adapter responsibility

`telegram-bot` is the Telegram-facing host for the provider-agnostic market core and the reusable `webapp-core` UI module.

It owns:

- Telegram identity authentication and signed Mini App `initData` verification;
- the Telegram webhook and Mini App BFF surface;
- the exact immutable `webapp-core` revision used by the host;
- Telegram-specific shell presentation, responsive material, viewport integration, and feedback;
- mapping verified Telegram identities to internal core users;
- deployment and Telegram runtime configuration.

It does not own products, prices, FX, broker routing, inventory accounting, reservations, orders, profitability, roles, or payment truth.

## Current Mini App behavior

The Mini App exposes one role-aware application:

- `client`: Market;
- `broker`: Market and Listings;
- `admin`: Market, Listings, and Administration.

The host performs one complete bootstrap and keeps catalog navigation local. POST operations require explicit top-level `status`, lock their owning section while pending, and surface loading/error feedback without allowing duplicate writes.

Checkout consumes authoritative quote, payment, and order state from core. The browser cannot confirm payment or select a broker.

## Presentation state

The Telegram adapter currently provides the fluid dark material layer around `webapp-core` markup, including:

- one moving workspace lens rather than per-tab fills;
- accessible 44px interaction targets and focus-visible boundaries;
- shared orb controls for loading, close, success, and error feedback;
- local-daypart material intensity without changing readable surface contrast;
- responsive catalog/navigation behavior for Telegram mobile viewports.

The adapter styles core-owned markup but does not duplicate its business state machine.

## Localization

Reusable application copy comes from `webapp-core`; product localization comes from core. The Telegram host resolves the incoming Telegram language tag and passes the canonical locale through the shared bootstrap/workspace contract.

Current full shared UI bundles are `en_US`, `uk_UA`, `ru_RU`, `es_ES`, and `pt_BR`, with recognized European skeleton locales falling back to English copy while preserving region identity. Telegram transport errors are bound to the resolved host locale rather than emitted as hard-coded English.

## Pricing and broker visibility

The client sees the administrator-owned market price, localized by core. Broker supply never raises that displayed price.

A product can be listed but unavailable: active broker inventory is enough for visibility, while checkout requires executable supply that passes the core-owned FX, margin, buffer, and reservation gates.

Brokers receive routing-oriented feedback from core without competitor ask disclosure. Exact ranking, allocation, profitability, and maximum executable ask remain server-owned decisions.

## Deployment boundary

The canonical runtime is the project VPS behind the shared 0xda-market edge. Deployment remains development-first and health-gated; Telegram webhook/menu registration is explicitly gated and is not an implicit side effect of every deployment.
