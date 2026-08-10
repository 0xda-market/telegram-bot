# Telegram Stars payments

## Scope

This integration is the Telegram payment adapter for 0xda-market digital goods.

It intentionally uses Telegram Stars (`XTR`) only. No Wallet Pay, crypto checkout, card provider, or other alternative payment rail is exposed inside the Telegram bot or Mini App for these digital goods.

Official Telegram references:

- Bot Payments API for digital goods: https://core.telegram.org/bots/payments-stars
- Bot API: https://core.telegram.org/bots/api
- Telegram Bot Platform Developer Terms: https://telegram.org/tos/bot-developers
- Telegram Stars Terms: https://telegram.org/tos/stars

## Telegram rules encoded as runtime invariants

The adapter treats these rules as code contracts:

1. Digital-goods invoices use currency `XTR`.
2. Stars invoices do not send a `provider_token`.
3. `pre_checkout_query` is handled synchronously and locally so the bot can answer within Telegram's required window.
4. The pre-checkout payload must have a valid HMAC signature and must match the Telegram user, Stars amount and unexpired order.
5. The Mini App `openInvoice` callback is never payment proof.
6. Only Telegram's server-side `successful_payment` update can start core payment confirmation.
7. The exact `telegram_payment_charge_id` is persisted through core as the external payment reference.
8. Fulfillment remains blocked in core until durable settlement verification and payment confirmation succeed.
9. A terminal charge that cannot be safely accepted is refunded with `refundStarPayment`.
10. A transient processing failure returns a webhook 5xx so Telegram can retry the same authoritative payment update.
11. `/paysupport` is available whenever real Stars payments are enabled.

## Signed invoice payload

The invoice payload contains no secret and no market pricing formula. It carries only the minimum claims required to bind the provider event to the accepted order:

```text
version.order_id.telegram_user_id.amount_xtr.expires_at.signature
```

The signature is HMAC-SHA256 truncated to 128 bits and URL-safe encoded. The signing key is server-only and must be at least 32 bytes.

The adapter enforces Telegram's 128-byte invoice payload limit before creating an invoice.

## Configuration

The adapter is disabled by default.

Required to enable it:

```text
TELEGRAM_STARS_PAYMENTS_ENABLED=1
TELEGRAM_PAYMENT_SIGNING_SECRET=<random secret, at least 32 bytes>
```

Optional:

```text
TELEGRAM_PAYMENT_SUPPORT_TEXT=<support instructions shown by /paysupport>
```

The matching core settlement provider must be configured independently:

```text
MARKET_PAYMENT_PROVIDER=telegram_stars
TELEGRAM_STARS_USDT_PER_STAR=<reviewed current valuation>
TELEGRAM_STARS_PAYMENT_SKUS=premium_3m,premium_6m,premium_9m
```

Do not hard-code or casually copy the Stars valuation. Review the current Telegram economics before every production activation or material change.

## Initial product restriction

The safe first rollout is limited to:

```text
premium_3m
premium_6m
premium_9m
```

The `stars_500`, `stars_1000`, and `stars_3000` products are intentionally not eligible for Stars checkout in the initial release. A Stars-for-Stars product needs a separate product, economic and Telegram-policy review.

## Safe activation order

Merging both PRs does not activate real payments.

Activate in this order:

1. Deploy the new core and bot code with all real payment flags still disabled.
2. Verify normal bot, Mini App, broker and manual-payment health remains unchanged.
3. Generate a new dedicated `TELEGRAM_PAYMENT_SIGNING_SECRET`; do not reuse the bot token, webhook secret or market API token.
4. Configure `TELEGRAM_PAYMENT_SIGNING_SECRET` and `TELEGRAM_STARS_PAYMENTS_ENABLED=1` on the Telegram bot.
5. Re-apply the Telegram webhook configuration so `pre_checkout_query` is included in `allowed_updates`.
6. Verify `/paysupport` is present and responds.
7. Review the current Stars developer economics and set the core `TELEGRAM_STARS_USDT_PER_STAR` value deliberately.
8. Leave `TELEGRAM_STARS_PAYMENT_SKUS` at the Premium-only default for the first rollout.
9. Enable `MARKET_PAYMENT_PROVIDER=telegram_stars` on core.
10. Perform one low-risk Premium 3-month end-to-end purchase with the intended production broker.
11. Verify the order, settlement, Telegram charge reference, broker order and fulfillment result before expanding traffic.

The bot should be payment-capable before core begins emitting Stars provider terms. This order avoids creating payment-pending orders that cannot open an invoice.

## End-to-end state machine

```text
quote
  -> accept
  -> payment_pending + durable settlement
  -> signed XTR invoice
  -> pre_checkout_query
       reject -> no charge
       accept -> Telegram may charge
  -> successful_payment
  -> trusted adapter confirmation
  -> core verifies settlement
  -> payment confirmed
  -> reserved inventory committed
  -> fulfillment
```

The browser never moves the order across the payment-confirmed boundary.

## Refund behavior

Automatic refund is intentionally narrow.

The adapter refunds when Telegram reports a successful Stars payment but core deterministically rejects it for a terminal reason such as:

- expired payment;
- immutable provider/currency/amount mismatch;
- different charge already attached to the order;
- payment provider not configured for the order;
- missing target order.

Malformed or tampered signed payloads on a successful `XTR` payment are also refunded because safe fulfillment is impossible.

Transient network/API failures are not immediately refunded. The webhook returns 5xx and Telegram can retry. This avoids refunding a payment that core may already have committed immediately before a timeout.

## Rollback

The safest rollback is configuration-only:

1. Unset `MARKET_PAYMENT_PROVIDER` in core first so new accepted orders stop receiving Stars provider terms.
2. Allow already-created Stars payment-pending orders to resolve or refund according to their signed expiry.
3. Disable `TELEGRAM_STARS_PAYMENTS_ENABLED` in the bot after no active Stars checkout remains.
4. Keep the signing secret available until every invoice signed with it is expired and reconciled.
5. Do not delete payment/settlement records or charge references during rollback.

Do not rotate or remove the signing secret while live signed invoices can still arrive as `pre_checkout_query` or `successful_payment` updates.

## Operational evidence to retain

For each completed payment, retain through core:

- market order id;
- immutable provider payment terms;
- settlement id/state;
- exact XTR amount;
- explicit USDT valuation snapshot;
- `telegram_payment_charge_id`;
- provider payment charge id when Telegram supplies it;
- invoice payload;
- fulfillment result/reference.

These fields are required for reconciliation, support and safe refund handling.
