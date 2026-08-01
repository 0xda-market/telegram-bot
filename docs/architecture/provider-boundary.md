# Provider boundary

The bot is a Telegram adapter around the provider-neutral 0xda Market API.

## Naming boundary

The adapter has one canonical Ruby namespace: `ZeroXDA::TelegramBot`. Source files live under `lib/zero_x_da/telegram_bot/`.

`client`, `broker`, and `admin` describe user roles or interaction flows inside the bot. They must not be used as names for the repository, runtime component, source directory, or top-level Ruby namespace.

## Direction of dependencies

```text
Telegram update
  -> TelegramBot
  -> MarketAPI anti-corruption layer
  -> generic external identity HTTP contract
  -> internal market user UUID
```

Telegram-specific identifiers and profile fields may exist in this repository. They must be translated at `MarketAPI` before a request reaches the core:

- authentication uses `provider`, `provider_user_id`, and `provider_data`;
- privileged actions use the internal `market.users.id` as `actor_user_id`;
- administrator targets are resolved to `target_user_id` inside the adapter;
- generic `identities[]` responses may be normalized into Telegram presentation fields only for bot UI code.

The core must never require Telegram tokens, Telegram webhook routes, Telegram DTO field names, or Telegram identifiers as domain ownership keys.
