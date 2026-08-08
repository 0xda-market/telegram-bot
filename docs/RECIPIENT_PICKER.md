# Telegram recipient picker

The Telegram Mini App uses Telegram's native peer picker as an optional convenience over the existing marketplace `username` recipient contract.

## Flow

1. The signed Mini App requests `POST /webapp/recipient-picker`.
2. The Telegram adapter verifies `initData`, creates a short-lived correlation token, and calls `savePreparedKeyboardButton` for one non-bot user with name and username sharing enabled.
3. The browser passes the returned prepared-button id to `Telegram.WebApp.requestChat`.
4. Telegram opens its native user picker and sends the selected `users_shared` service message to the bot webhook.
5. The webhook correlates `from.id + request_id` with the short-lived picker request.
6. The Mini App polls `GET /webapp/recipient-picker/:token` until the selection is available, then fills the existing `username` recipient input.

The correlation state is deliberately ephemeral and process-local. It expires after two minutes and contains only the requester id, request id, expiration, and the selected Telegram identity fields required by the UI. It is not marketplace truth and is never persisted to core.

## Compatibility and privacy

The shared checkout contract remains `self` or `username`; core does not depend on Telegram peer-picker APIs. If `requestChat` is unavailable, the shared UI falls back to manual `@username` entry. A selected user without a Telegram username cannot currently satisfy the marketplace contract, so the UI asks the buyer to choose another recipient or use the manual fallback.

The picker endpoint is bound to signed Telegram `initData`, and a result token can only be read by the same Telegram requester that created it. The browser never receives the bot token and never calls Bot API directly.
