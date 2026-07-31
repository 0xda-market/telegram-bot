# Currency pricing model

The Telegram adapter uses the same pricing vocabulary as core:

```text
currency resource
  -> generic price write
  -> currency resource with `usdt_per_unit`
```

There is no separate `fx_rate` resource in the bot. `MarketAPI#currencies` returns the core `currency` resources unchanged, and every administrator write uses `MarketAPI#apply_prices` with the currency resource ID as `sku`.

## Telegram compatibility commands

The public commands `/rates` and `/set_rate` remain available to preserve the existing Telegram contract. Their names are compatibility aliases only:

```text
/rates
  -> GET /v1/currencies

/set_rate UAH 0.024
  -> resolve registered currency code UAH
  -> POST /v1/admin/prices
       prices: [{ sku: "uah", amount_usdt: "0.024" }]
```

The command menu and response copy describe these values as currency prices relative to the USDT base. The adapter does not transform a currency into another resource type.

## Validation and failure behavior

A write is accepted only for a currency returned by the core catalog. Unknown currency codes are rejected before a price mutation. This prevents `/set_rate` from silently treating arbitrary strings as product identifiers.

Core remains authoritative for administrator authorization, price validation, persistence and audit fields. Telegram only resolves localized input and presentation.
