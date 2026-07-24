# mcp-control integration

The VPS-local `mcp-control` agent observes the bot through the existing read-only health endpoint:

```text
http://127.0.0.1:10001/health
```

The bot does not connect to `mcp-control`, receive its credentials, or expose a new socket. Docker publishes container port `10000` only on host loopback port `10001`; `mcp-control` performs a bounded `local-http-v1` GET probe.

Canonical server identity:

```text
0xda-market-bot
```

The current runtime and log adapters remain `none-v1` until one stable Docker observation contract is selected. This document intentionally adds no webhook, public port, database, or write capability.
