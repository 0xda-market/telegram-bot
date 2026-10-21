# VPS bot deployment

The Telegram client runtime is deployed on the shared `nilx-edge` network. Production and development are independent runtime identities and may be active at the same time.

## Runtime identities

| Environment | Telegram identity | Edge alias | Core target | Public base URL |
| --- | --- | --- | --- | --- |
| `production` | `0xda-market` | `market-bot-production` | `market-api-production:10000` | `https://0xda-market.nilx.one/bot` |
| `development` | `0xda-market-test` | `market-bot-development` | `market-api-development:10000` | `https://0xda-market.nilx.one/bot-test` |

Both containers listen on internal port `10000`. No host port is published; Caddy reaches them through the external Docker network. This avoids a shared host-port or Docker-DNS alias and allows both bots to stay online concurrently.

## Ownership boundary

This repository owns the bot process, Telegram webhook/BFF behavior, release lifecycle, runtime secrets and its two Docker identities. `0x0sky/infra` owns public HTTPS routing and must route the two public prefixes to the matching aliases.

The bot consumes `0xda-market/core`; it does not own the core runtime or its public edge. Server-side bot traffic reaches the matching core directly over `nilx-edge`, so the development API does not need a public hostname.

## GitHub delivery

The **active development** deployment is manual-only through
`.github/workflows/deploy-vps.yml` (`Deploy development via infra`). The product
repository no longer uses SSH for this flow. It checks for successful push CI
on the exact `master` commit, builds one GHCR image, and dispatches that
immutable digest to `aiaiaiai-org/infra` as workload `market-bot-test`.

GitHub Environment: `development`. Keep its own
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `MARKET_API_TOKEN`
secrets and `TELEGRAM_BOT_USERNAME`, `PUBLIC_URL`, `MARKET_API_URL`
variables. The organization-level `INFRA_DEPLOY_TOKEN` must be scoped to
the producer repositories and must have dispatch and recipient-read access
on infra. Product repositories must **not** receive VPS `SSH_*` secrets.

A public key issued by infra for the contracted server encrypts the per-run
bot credentials, but **never GHCR registry credentials**. Registry access belongs
to `aiaiaiai-org/infra`: the target `edge-prod-1` Environment needs its own
`GHCR_PULL_TOKEN` with `read:packages` access to the private
`ghcr.io/0xda-market/telegram-bot` package, and the matching `GHCR_PULL_USER`.
The producer job's short-lived `github.token` must not be sent to infra.
Only infra's target GitHub Environment holds the key to decrypt the envelope.
Infra owns network, port, host selection, activation, rollback and health checks.

The configured test bot identity must be a username, not a `t.me` URL:
`zeroxda_market_test_bot`; `PUBLIC_URL` is
`https://0xda-market.nilx.one/bot-test` and `MARKET_API_URL` is
`http://market-api-development:10000`. The Bot API token and its
`MARKET_API_TOKEN` must match the development Core `PUBLIC_API_TOKEN`
credential. No production values may be reused in development.

Merge and successful CI do not activate the bot. Infra dispatch acceptance
does not prove completion: inspect the infra workflow for the health result.
Telegram webhook/menu registration remains a separate explicit operation.

**Production deployment is temporarily frozen by this workflow change.**
The old manual `production_tag` workflow is removed; already running production
is not altered by merging, but another production release requires its own
reviewed infra release contract and separately authorized activation. The old
VPS-specific paths below are historical context only and must not be used to
bypass infra.

## VPS layout

```text
/opt/0xda-market-bot/environments/
  development/
    current -> releases/<sha>
    releases/
    shared/.env
  production/
    current -> releases/<sha>
    releases/
    shared/.env
```

There is no global `active-environment` switch for the bot. Development and production are separate Compose projects:

```text
zero-x-da-market-bot-development
zero-x-da-market-bot-production
```

## Runtime files

Development uses:

```env
DEPLOY_ENV=development
MARKET_CORE_ENV=development
MARKET_EDGE_NETWORK=nilx-edge
PORT=10000
TELEGRAM_BOT_TOKEN=<0xda-market-test token>
TELEGRAM_BOT_USERNAME=<test bot username without @>
TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS=3600
TELEGRAM_WEBHOOK_SECRET=<development secret>
MARKET_API_URL=http://market-api-development:10000
MARKET_API_TOKEN=<synchronized by deploy>
REGISTER_TELEGRAM_WEBHOOK=0
REGISTER_TELEGRAM_WEBAPP=0
PUBLIC_URL=https://0xda-market.nilx.one/bot-test
```

Production uses the same schema with:

```env
DEPLOY_ENV=production
MARKET_CORE_ENV=production
MARKET_API_URL=http://market-api-production:10000
PUBLIC_URL=https://0xda-market.nilx.one/bot
```

`MARKET_CORE_ENV` selects which core environment supplies the server API credential. It defaults to `DEPLOY_ENV` when omitted. This keeps bot identity separate from the core environment contract without duplicating credentials in GitHub.

Protect runtime files with mode `0600`.

## Edge contract

After both workloads are deployed, the shared edge should expose:

```text
https://0xda-market.nilx.one/bot/*
  -> market-bot-production:10000/*

https://0xda-market.nilx.one/bot-test/*
  -> market-bot-development:10000/*
```

Caddy should strip the public prefix. Consequently:

```text
/bot/telegram/webhook      -> /telegram/webhook
/bot/webapp/               -> /webapp/
/bot-test/telegram/webhook -> /telegram/webhook
/bot-test/webapp/          -> /webapp/
```

The Mini App browser never receives `TELEGRAM_BOT_TOKEN` or `MARKET_API_TOKEN`.

## Deployment verification

`deploy.sh` verifies:

- the Compose contract;
- container health;
- immutable release SHA label;
- the environment-specific edge alias;
- Telegram bot identity and webhook URL;
- authenticated access to the matching core environment.

The deployment does not mutate Caddy or DNS. Public-edge activation remains a separate `0x0sky/infra` deployment.

## Telegram registration

`REGISTER_TELEGRAM_WEBAPP=1` configures the private-chat menu button to open `${PUBLIC_URL}/webapp/`. Keep registration disabled until the corresponding public edge route is live and healthy. Webhook and Mini App registration are external mutations and belong to the explicit deployment/rollout step.
