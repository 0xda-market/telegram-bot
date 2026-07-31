# HTTP runtime boundary

The Telegram bot service exposes a Rack adapter named `TelegramBotHTTPApp`.

```text
GET  /
GET  /health
POST /telegram/webhook
/webapp/* -> TelegramMiniApp
```

`TelegramBotHTTPApp` owns the bot-facing HTTP runtime. `TelegramMiniApp` is a separate browser surface with its own signed-session and BFF contract. The explicit names prevent the webhook runtime from being confused with the WebApp entities.

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

`TelegramBotHTTPApp` receives the validated username as an immutable constructor dependency. It never calls Telegram while handling `GET /`, so a later Telegram API outage cannot turn the landing route into a request-time `503`.

Production and other stable runtimes should set `TELEGRAM_BOT_USERNAME` explicitly. The boot-time `getMe` fallback preserves compatibility for existing development environments while they adopt the variable.

## Compatibility

`HTTPApp` and `WebApp` remain compatibility aliases for integrations that still require the previous constants. `config.ru` and all new code use `TelegramBotHTTPApp` directly. The aliases do not own behavior and can be removed only as an explicit breaking change.

## Webhook contract

The webhook route remains unchanged:

- `POST /telegram/webhook`
- `X-Telegram-Bot-Api-Secret-Token` is required
- a valid request is acknowledged before asynchronous update processing
- invalid JSON returns `400`
- unauthorized requests return `401`

Mini App routes are delegated before the bot webhook router and are documented in `telegram-mini-app.md`.
