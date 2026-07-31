# HTTP runtime boundary

The Telegram bot service exposes a Rack HTTP adapter named `HTTPApp`.

```text
GET  /
GET  /health
POST /telegram/webhook
```

The adapter is not a Telegram Mini App. A future Mini App must be implemented as a separate surface with its own Telegram init-data signature validation and browser-facing contract.

## Boot-time bot identity

The root route redirects to the environment bot through a username resolved before Rack starts serving requests:

```text
TELEGRAM_BOT_USERNAME configured
  -> validate once

TELEGRAM_BOT_USERNAME absent
  -> Telegram getMe once during boot
  -> validate once

GET /
  -> static https://t.me/<username> redirect
```

`HTTPApp` receives the validated username as an immutable constructor dependency. It never calls Telegram while handling `GET /`, so a later Telegram API outage cannot turn the landing route into a request-time `503`.

Production and other stable runtimes should set `TELEGRAM_BOT_USERNAME` explicitly. The boot-time `getMe` fallback preserves compatibility for existing development environments while they adopt the variable.

## Compatibility

`WebApp` remains a compatibility alias for integrations that still require `web_app.rb`. `config.ru` and all new code use `HTTPApp` directly. The alias does not own behavior and can be removed only as an explicit breaking change.

## Webhook contract

The webhook route remains unchanged:

- `POST /telegram/webhook`
- `X-Telegram-Bot-Api-Secret-Token` is required
- a valid request is acknowledged before asynchronous update processing
- invalid JSON returns `400`
- unauthorized requests return `401`
