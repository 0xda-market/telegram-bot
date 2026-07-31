# Telegram Mini App

The repository owns two separate runtimes:

```text
TelegramBotHTTPApp
  -> bot landing redirect
  -> health
  -> Telegram webhook

TelegramMiniApp
  -> browser assets under /webapp/
  -> signed session bootstrap
  -> quote, accept and order refresh BFF routes
```

The Mini App is the Telegram-specific shell in the three-entity WebApp architecture:

```text
0xda-market/core /webapp-core/index.js
  ├─ standalone WebApp
  └─ telegram-bot/webapp
```

The shell imports the shared `webapp-core` browser module. It owns Telegram SDK initialization, theme variables, viewport events, haptics and transmission of `Telegram.WebApp.initData`. It does not implement catalog pagination or copy the shared engine.

## Complete catalog bootstrap

Opening `/webapp/` performs exactly one catalog request:

```text
GET /webapp/bootstrap
X-Telegram-Init-Data: <Telegram.WebApp.initData>

telegram-bot
  -> validate initData
  -> authenticate Telegram identity with core
  -> GET core /v1/webapp/bootstrap
  -> return the complete snapshot
```

The browser stores the full array in `CatalogStore`. With 1,488 products and portrait page size six, page one, page two and page three are local array slices. Search, category filters, previous, categories/home, next and viewport page-size changes do not call the network.

Portrait shows six products. Landscape uses twelve, and wide landscape uses eighteen. Changing page size preserves the first visible product.

## Checkout boundary

Browsing is snapshot-based; settlement is not. Selecting a product is local. An explicit quote request sends only the stable SKU to the BFF. The server loads a current complete snapshot, verifies that the product still exists and has a price, then creates the existing manual-fulfillment intent and quote.

```text
local selection
  -> POST /webapp/quotes
  -> current quote
  -> POST /webapp/quotes/:id/accept
  -> order
  -> GET /webapp/orders/:id
```

The existing `PurchaseFlow` keeps internal-user ownership checks and quote expiry behavior. The browser never receives `MARKET_API_TOKEN` or the Telegram bot token.

## Telegram session validation

Every BFF request carries raw `Telegram.WebApp.initData`. `TelegramWebAppAuth`:

- rejects malformed or duplicate fields;
- verifies the HMAC-SHA-256 `hash` using the bot token-derived `WebAppData` secret;
- checks `auth_date` freshness;
- parses the signed user and optional chat objects;
- rejects requests before any market operation when validation fails.

The default maximum session age is 3,600 seconds and is configurable with `TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS`.

## Dependency order

The Telegram Mini App depends on the core snapshot/runtime change. Merge and deploy order is:

1. `0xda-market/core` WebApp snapshot/runtime PR;
2. `0xda-market/telegram-bot` Mini App PR;
3. configure the BotFather Mini App URL only after both development deployments are healthy.
