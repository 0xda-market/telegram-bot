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

The bootstrap transport preserves the complete `{ data, meta }` document. `webapp-core` converts it into an explicit `{ catalog, locale, session, currencies }` context. Resource transports unwrap their `data` resources. Every successful Mini App `POST` document must first expose top-level `status: "ok"`. Durable writes always pass through verified Telegram authentication and the core API; no market state is authoritative in the browser.

Every BFF request carries raw `Telegram.WebApp.initData` in `X-Telegram-Init-Data`. The server validates the HMAC, age and verified Telegram user before market operations. The public session never exposes the internal market UUID or bot token.

## Localization contract

Telegram supplies the raw user language through `initDataUnsafe.user.language_code`. The host passes that value to `webapp-core`, where `uk`, `uk-UA` and `uk_UA` resolve to `uk_UA`; unsupported locales fall back to `en_US`.

The shared package owns reusable interface translations for Market, quantity-aware checkout, payment-pending state, Listings, role navigation, Administration, Products and Prices. Product names remain core-owned localized data. Stable category identifiers remain unchanged, while the shared presentation layer renders human-readable labels such as `Криптоактиви` instead of `crypto_asset`.

The adapter owns only the first frame before the immutable shared module has loaded. `shell-localization.js` applies the same Ukrainian or English loading copy immediately, preventing an English flash for Ukrainian users. After module import, the shared package becomes authoritative for all visible copy.

## Entry-point contract

Every authenticated private-chat user receives a `web_app` launch action in the `/start` and `/status` account card. The action opens the adapter-owned `/webapp/` URL derived from `PUBLIC_URL`; the verified session then selects the client, broker or admin workspace.

This in-chat entry point is the baseline access path and does not depend on global Telegram menu-button registration. `REGISTER_TELEGRAM_WEBAPP=1` may still install the same URL as the global chat menu button, but that registration remains an optional deployment concern rather than a prerequisite for opening the Mini App.

The legacy inline `/buy` callback remains compatible during migration. When connected to the payment-aware core contract it also uses the marketplace quote and order APIs, with quantity `1`, and stops at `payment_pending` rather than attempting fulfillment before payment.

## Role workspace contract

The Telegram host passes only the verified bootstrap context into the shared workspace package:

- `client` mounts the Market surface;
- `broker` mounts Market and Listings;
- `admin` mounts Market, Listings and Administration.

The host moves the broker workspace out of the market shell before mounting navigation so every section remains an independent surface. The navigation cannot grant capabilities: unavailable sections are filtered by the verified role inside `webapp-core`.

## Mobile input contract

The immutable shared module owns field semantics and keyboard visibility. Quantity, listing amount, client price and product position use native numeric inputs with decimal or integer `inputmode` as appropriate; identifiers remain text inputs. While a text field is focused, the shared handler follows `VisualViewport` changes and centers the field if the on-screen keyboard would cover it. This applies equally to checkout, broker and administrator surfaces, including fields mounted after bootstrap.

The Telegram shell keeps numeric controls at a 16 px font size on coarse-pointer devices so iOS WebViews do not add a second focus zoom while the viewport is moving. Telegram SDK viewport callbacks remain responsible for catalog pagination only; they do not duplicate keyboard positioning logic.

## Marketplace checkout contract

The client checkout uses three signed BFF operations:

- `POST /webapp/quotes` with `sku`, `quantity` and `locale`;
- `POST /webapp/quotes/:quote_id/accept`;
- `GET /webapp/orders/:order_id`.

The browser never sends `actor_user_id`. `TelegramWebAppService` verifies `initData`, authenticates the Telegram user through core, and supplies the stable internal UUID server-side.

The BFF maps those operations to the liquidity-backed core endpoints:

- `POST /v1/market/quotes`;
- `POST /v1/market/quotes/:quote_id/accept`;
- `GET /v1/market/orders/:order_id`;
- `POST /v1/market/orders/:order_id/execute` only for eligible post-payment retries.

Quote acceptance now returns a `payment_pending` order. The Telegram adapter returns that resource unchanged and does not call execute. The shared UI renders the authoritative amount, currency and expiration from the core payment document, while inventory remains reserved.

Payment confirmation is not a Telegram browser operation. There is no `confirmPayment` transport method and no browser route that can assert success. A trusted payment-provider or operator adapter confirms payment directly against core. After confirmation, core commits inventory and starts provider-neutral fulfillment; the Mini App only refreshes the resulting order state.

`PurchaseFlow#refresh` also returns a payment-pending order without execution. It may invoke the existing execute endpoint only after core reports an executable `accepted`, `pending` or retryable `failed` state.

Core owns product availability, listing allocation, inventory reservation, quote expiration, client pricing, payment state, order ownership and fulfillment state. The Telegram adapter does not select a broker, inspect supply economics, calculate inventory balances or trust a browser payment claim.

The shared UI keeps quantity editable only before a quote is created. Once core reserves inventory, the displayed total, payment terms and expiration are authoritative.

## Broker inventory contract

The signed listing lifecycle remains:

- `GET /webapp/broker/listings`;
- `POST /webapp/broker/listings`;
- `PATCH /webapp/broker/listings/:listing_id`;
- `DELETE /webapp/broker/listings/:listing_id`.

Listing responses include total, available, reserved and sold quantities. The browser renders those balances but never mutates them directly. Core enforces the inventory equation and rejects a total-quantity reduction below already reserved or sold inventory.

Unpaid accepted orders remain in `reserved_quantity`. They move to `sold_quantity` only after trusted payment confirmation.

## Administrator catalog contract

The Products capability uses four signed BFF operations:

- `POST /webapp/admin/products`;
- `GET /webapp/admin/products`;
- `PATCH /webapp/admin/products/:sku`;
- `PUT /webapp/admin/products/:sku/localizations/:locale`.

Product creation submits the stable SKU, locale-neutral attributes and one initial localization. The shared controller always creates an `inactive` product; activation is a separate administrator edit after pricing and broker supply are ready.

The browser submits product or localization versions, but never an actor UUID or role. `TelegramWebAppService` verifies `initData`, resolves the Telegram identity to the internal core user and supplies that UUID server-side. Core performs the definitive administrator check, duplicate-SKU rejection and optimistic-concurrency enforcement.

Product updates cannot alter SKU or price state. Localization writes are independent from product versions.

## Administrator pricing contract

The Prices capability uses complete documents so proposal metadata is never discarded:

- `GET /webapp/admin/prices/proposal`;
- `POST /webapp/admin/prices`;
- `GET /webapp/admin/prices/history`.

The proposal returns one monotonic revision for the current append-only price ledger. The browser submits that exact revision with only the fields changed since the proposal loaded. Core appends the submitted subset as one atomic batch and rejects a stale revision before appending any row; unrelated unpriced products do not block the save. The BFF resolves the administrator UUID only after signed Telegram authentication; the browser sends neither an actor UUID nor a trusted role.

Rejected Mini App POSTs use top-level `status: "error"` alongside the existing error code and message. The Telegram transport rejects a successful POST document that omits `status`. While a write is pending, `webapp-core` marks the complete owning section inert and `aria-busy`, and this host renders that shared loading state with a visible spinner.

Existing `/apply_price`, `/apply_prices`, `/rates` and `/set_rate` commands remain Telegram compatibility surfaces over the same core pricing model. They do not own a separate price store or currency-rate contract.

A real payment rail, payment instructions, wallet addresses, acquiring or blockchain callbacks, refunds, disputes, payout execution and automated settlement remain outside this adapter change.

## Immutable module dependency

`webapp/app.js` imports one `webapp-core` module from an exact Git commit revision. Relative imports resolve to the same immutable revision. Production does not load a mutable default-branch URL.

The pinned revision is updated only in a reviewed Telegram PR after the matching `webapp-core` checks are green. No separate `/web-app/*` UI module or `/webapp-core/*` engine module is required from `core`.
