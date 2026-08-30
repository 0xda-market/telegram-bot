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

Deployment is manual-only through `.github/workflows/deploy-vps.yml`.

- `development` deploys the exact commit selected by GitHub's workflow ref selector.
- `production` must be dispatched from `master` and requires an explicit immutable Git tag.
- Merge does not deploy either environment.
- Each environment has an independent concurrency group, release directory and `current` symlink.
- A failed activation attempts to restore the previous release of that same environment only.

Required GitHub Environment configuration for both `development` and `production`:

- secret `SSH_HOST`;
- secret `SSH_USER`;
- secret `SSH_PRIVATE_KEY`;
- variable `SSH_DEPLOYMENT_PATH=/opt/0xda-market-bot`;
- variable `SSH_PORT=22022`.

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
