# Trading Lab → 4x-errors: zero-token diagnostics

This bot captures errors from **paper-only Trading Lab** into the shared
`errors.v1` collector without a 4x-errors ingest token or database credentials.

## Configure once

1. Deploy the independent 4x-errors collector with `DATABASE_URL` pointing
   to the central 4x-errors Supabase PostgreSQL. Optionally configure the
   **collector-only** `ERRORS_PROJECT_DATABASE_URLS` map to dedicated databases.
2. Configure the collector's `BROWSER_INGEST_ORIGINS` to allow the public
   project `0xda-market/telegram-bot` from `https://0xda-market.nilx.one`.
   This is an abuse filter, **not** proof of sender identity.
3. Put `FOUR_X_ERRORS_URL`, a **public GitHub production environment variable**
   containing the verified collector's bare HTTPS origin, in
   `0xda-market/telegram-bot`. **No `FOUR_X_ERRORS_TOKEN` exists or is needed.**
4. Once Full CI is green, merge the bot and infra contracts with explicit
   approval. Publish a new production candidate then manually reconcile the bot
   only after separately authorizing deployment.

## What we report

The server-only reporter sends POST `/v1/browser/events` (the public untrusted
ingest path) with an `Origin` header equal to the bot's public HTTPS origin.
It emits `market.trading.request.rejected` (422),
`market.trading.upstream.unavailable` (non-200, including 502), or
`market.trading.transport.failed` (timeout, connection or invalid JSON).

Payloads contain only the semantic error ID, a constant generic message,
operation name, duration, status/exception **class**, and a random correlation
UUID also sent to Trading Lab. They never include user IDs, Telegram initData,
trader codes, request bodies, raw upstream responses, tokens, arbitrary
exception messages or stacktraces. This is a bounded, asynchronous in-memory
reporter; collector failure never changes the paper trading result.

Because public Origin can be forged, enforce per-IP/per-project rate limits,
global edge/WAF budgets, quotas and monitoring on the collector. There is **no
public DB access**; neither browser nor bot gets PostgreSQL credentials.

## Read events after deployment

```sql
select observed_at, error_id, source, severity, correlation_id, context
from public.error_events
where project = '0xda-market/telegram-bot'
order by observed_at desc limit 30;
```

This query assumes the **central** collector database is selected; if the
collector's operator has assigned a dedicated database to this project, query
that store instead. Previous 502 responses were never ingested retroactively.

A real end-to-end proof requires one new controlled paper replay yielding
502, a successful collector HTTP acknowledgement, and the matching persisted
row. Tests with a local fake collector do **not** establish production delivery.

---

© 2026 aiaiaiai · aiaiaiai.org
