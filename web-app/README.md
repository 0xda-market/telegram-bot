# Telegram Web App Adapter

This directory defines the Telegram host adapter for the shared [`0xda-market/web-app`](https://github.com/0xda-market/web-app) interface core.

The shared Web App is not a standalone site and does not contain Telegram-specific behavior. The Telegram bot embeds that interface, authenticates the Telegram user, resolves the existing market role, and supplies a verified host context.

## Responsibilities

The Telegram adapter owns:

- validation of `Telegram.WebApp.initData`;
- mapping a Telegram identity to the internal market user;
- loading the persisted `client`, `broker`, or `admin` role;
- issuing a short-lived session for Web App server actions;
- opening role-aware entry points from bot buttons;
- Telegram theme, viewport, back, close, and external-link integration;
- Telegram-specific notifications and command flows;
- protecting API credentials and bot tokens from browser code.

It does not own:

- marketplace UI components;
- product, offer, inventory, or order domain rules;
- role assignment;
- broker pricing policy;
- persistent marketplace records.

## Roles and entry points

`broker` is an existing market role, not a channel or adapter type.

The bot exposes entry points according to the verified role:

- `client`: Buy;
- `broker`: Buy and Add Offer;
- `admin`: Buy, Add Offer, and administration controls.

Opening an entry point does not grant access. Every privileged server action revalidates the signed Telegram session and the current internal role.

## Broker offer flow

For the first broker-focused prototype, the Telegram adapter opens the shared Web App at the Add Offer entry point.

The broker then:

1. selects a real product from the shared catalog;
2. enters quantity;
3. enters the amount in the currency in which the broker actually trades;
4. confirms or changes the currency suggested from locale;
5. stores the offer locally until persistent APIs are introduced.

Locale is only a defaulting signal. A Ukrainian-language broker may quote in RUB, USDT, EUR, or another supported currency.

The shared interface retains the original `amount + currency` and may show a provisional USDT equivalent. USDT is the internal broker-side comparison unit; the client-facing display currency belongs to the client journey.

## Security boundary

The browser receives neither `TELEGRAM_BOT_TOKEN` nor `MARKET_API_TOKEN`.

The adapter validates Telegram launch data server-side, resolves the internal user, and passes only the minimum verified session and capability context required by the shared Web App.

The Web App must treat host-provided capabilities as presentation hints. Backend authorization remains authoritative for every write.

## Integration boundary

The Telegram-specific shell may provide implementations for:

- session bootstrap;
- authenticated API transport;
- host navigation;
- back and close actions;
- theme and viewport updates;
- opening payment or external fulfillment surfaces;
- success, error, and notification feedback.

These implementations satisfy the shared Web App host contract without introducing Telegram SDK calls into the reusable interface core.