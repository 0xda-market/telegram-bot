# Trading Lab → 4x-errors diagnostics

The Telegram-bot's server-side Trading Lab adapter emits **errors.v1** events when
a paper replay is rejected (422), an upstream HTTP response fails (including
502/503), or the bot encounters a JSON or transport failure (including timeouts).
There are no trading orders, browser credentials, direct database writes or
changes to the paper simulation model.

## Producer configuration (production)

Configure both values in the GitHub **production** environment of
`0xda-market/telegram-bot`, then publish the attested production candidate:

- `FOUR_X_ERRORS_URL` — environment **variable**, bare HTTPS origin of the
  independently deployed 4x-errors collector (e.g. its actual verified hostname).
- `FOUR_X_ERRORS_TOKEN` — environment **secret**, high-entropy project-bound
  ingest token (project **`0xda-market/telegram-bot`**).

The collector must first configure the SHA-256 digest of that token for the
**exact** project key in `INGEST_TOKEN_DIGESTS` and be able to persist into its
own database. The bot **never** gets a PostgreSQL/Supabase credential. An unconfigured reporter is null in code, but **the production publication
workflow requires both values** because Infra rejects empty mapped secrets.
Provision the collector and its project-bound token before merging/activating
the updated delivery contract. Tokens must be 43–128 base64url characters.

Delivery is asynchronous via a fixed 32-event memory queue, one worker and
sub-second HTTP timeouts; there is **no retry** on collector failure. Events can
be lost on shutdown or collector downtime, so this is diagnostic best-effort,
not a durable audit log. The collector is independent of Market Core and OKX.

An event records only a semantic failure ID, an operation name, HTTP status or
exception **class**, elapsed milliseconds and a fresh random correlation UUID.
It deliberately excludes Telegram initData/user IDs, trader codes, tokens,
request/response bodies, exception messages and stack traces.

## Reading delivered events

After the collector and producer are configured, use the **4x-errors** Supabase
project's SQL editor (read-only) to inspect:

```sql
select observed_at, error_id, source, severity, correlation_id, context
from public.error_events
where project = '0xda-market/telegram-bot'
order by observed_at desc
limit 30;
```

Expected error IDs:
- `market.trading.request.rejected` — 422/validation or budget limit
- `market.trading.upstream.unavailable` — non-200/unexpected Trading Lab HTTP response
- `market.trading.transport.failed` — timeout, connection or invalid JSON

Use the correlation ID when inspecting the Trading Lab service's corresponding
upstream event once it is also instrumented. Until the producer and collector
are deployed, older events cannot appear retroactively.

## Activation and acceptance

1. Verify collector `/health` and `/ready`; provision the project-specific
   trusted ingest token and its collector-side hash.
2. Merge the bot instrumentation and the Infra delivery contract; verify exact
   Full CI and deploy validation.
3. Populate GitHub production variable/secret and publish the candidate;
   manually reconcile `market-bot-production` after explicit deployment approval.
4. Trigger one paper copy simulation that returns 502. Read a new sanitized
   `market.trading.*` event with the same timeframe and no private data.
5. Test collector-offline behaviour: the primary API must still respond with
   its original error, not an extra collector error.

This PR does not merge, deploy, provision tokens, send synthetic production
events, or enable live exchange trading.

---

© 2026 aiaiaiai · aiaiaiai.org
