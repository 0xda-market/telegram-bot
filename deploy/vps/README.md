# VPS bot deployment

The client bot runs on the same VPS as the provider-agnostic `0xda-market` core.
Caddy in the core stack owns public HTTPS and forwards `/bot/*` over the private
external network `nilx-edge` to the alias `market-bot`.

The VPS is the canonical bot runtime. Render configuration is no longer part of
the supported deployment path.

## Current deployment contract

Automated deployment is development-only:

| GitHub environment | Branch | Telegram bot | Runtime directory |
| --- | --- | --- | --- |
| `development` | `master` | test bot | `environments/development` |

Production directories remain reserved, but the current workflow does not deploy
`release*` or production. Enabling production requires a separate reviewed change
paired with the core production workflow.

`DEPLOY_ENV` is the only runtime environment marker. It must match the runtime
file and its VPS directory.

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

/opt/0xda-market-runtime/active-environment
```

The core repository owns the `Switch VPS Environment` controller. A bot deploy
never switches the active environment by itself.

The bot binds to `127.0.0.1:10001` for local smoke checks and exposes internal
port `10000` as `market-bot` on the shared edge network.

## GitHub development environment

Configure `development` with:

- secret `VPS_HOST`;
- secret `VPS_USER=deploy`;
- secret `VPS_SSH_PRIVATE_KEY`;
- variable `VPS_BOT_DEPLOY_PATH=/opt/0xda-market-bot`.

The workflow uses fixed SSH port `22022`. Do not add `VPS_PORT`.

## Runtime file

```text
/opt/0xda-market-bot/environments/development/shared/.env
```

Example:

```env
DEPLOY_ENV=development
MARKET_EDGE_NETWORK=nilx-edge
PORT=10000
TELEGRAM_BOT_TOKEN=<test bot value>
TELEGRAM_BOT_USERNAME=<test bot username without @>
TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS=3600
TELEGRAM_WEBHOOK_SECRET=<development value>
MARKET_API_URL=https://0xda-market.nilx.one
MARKET_API_TOKEN=<development core API value>
REGISTER_TELEGRAM_WEBHOOK=0
PUBLIC_URL=https://0xda-market.nilx.one/bot
```

`TELEGRAM_BOT_USERNAME` keeps Rack boot and the public root redirect independent
from Telegram API availability. Existing environments without it remain
compatible: the process calls `getMe` once during boot and then stores the
validated username in memory. Request handling never calls `getMe`.

`TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS` limits the age of signed
`Telegram.WebApp.initData` accepted by the Mini App BFF. The default is one hour.
The browser never receives `TELEGRAM_BOT_TOKEN` or `MARKET_API_TOKEN`.

Protect the file:

```sh
chown deploy:deploy /opt/0xda-market-bot/environments/*/shared/.env
chmod 0600 /opt/0xda-market-bot/environments/*/shared/.env
```

Keep `REGISTER_TELEGRAM_WEBHOOK=0` until local and public smoke checks pass.
Webhook and BotFather Mini App registration remain separate reviewed operations.

## Deployment behavior

After green CI, `master` stages or refreshes `development`.

- an inactive release is built but not started;
- the active development bot is refreshed and health-gated;
- a failed active refresh attempts to restart the previous release;
- only the active bot joins the edge network with the `market-bot` alias;
- deployment never changes DNS, Caddy routing, Telegram webhook state or
  BotFather Mini App settings.

The core WebApp snapshot/runtime change must be deployed before this bot change,
because `/bot/webapp/` imports `/webapp-core/index.js` and its BFF loads
`/v1/webapp/bootstrap` from core.

## Smoke checks

```sh
cat /opt/0xda-market-runtime/active-environment
curl -i http://127.0.0.1:10001/
curl -i http://127.0.0.1:10001/health
curl -i http://127.0.0.1:10001/webapp/
curl -i https://0xda-market.nilx.one/webapp-core/index.js
curl -i https://0xda-market.nilx.one/v1/webapp/bootstrap?locale=uk_UA\&currency=USDT
curl -i https://0xda-market.nilx.one/bot/
curl -i https://0xda-market.nilx.one/bot/health
curl -i https://0xda-market.nilx.one/bot/webapp/
cd /opt/0xda-market-bot/environments/development/current/deploy/vps
docker compose ps
docker compose logs --tail 200 bot
```

The root route must return a static `302` to the configured environment bot. The
Mini App shell must return `200`; its bootstrap BFF intentionally returns `401`
without signed Telegram init data. Caddy strips the `/bot` prefix, so public
`/bot/telegram/webhook` maps to internal `/telegram/webhook` and
`/bot/webapp/` maps to internal `/webapp/`.

The complete cross-repository verifier lives in the active core release:

```sh
sudo -u deploy \
  bash /opt/0xda-market/environments/development/current/deploy/vps/verify.sh
```

## Scheduled price digest

The price digest is hosted on the VPS through systemd, not Render.

Install or refresh the timer as root:

```sh
cd /opt/0xda-market-bot/environments/development/current/deploy/vps
sudo ./install-systemd.sh
```

The timer runs at 05:00 and 06:00 UTC. `run-price-digest.sh` executes only when
production is active; `bin/send_price_digest` selects the run corresponding to
07:00 CET/CEST.

```sh
systemctl list-timers 0xda-market-price-digest.timer
journalctl -u 0xda-market-price-digest.service --since today
```

## Operations

Reboot, HTTPS, health, logs, backups and rollback are documented centrally in
`0xda-market/0xda-market`:

- `deploy/vps/OPERATIONS.md`

Do not disable or delete the previous host as part of an application deployment.
That is a separate irreversible operation requiring explicit owner approval.
