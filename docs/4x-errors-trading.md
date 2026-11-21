<!-- © 2026 aiaiaiai · aiaiaiai.org -->

# Trading Lab diagnostics

Market Telegram Bot forwards a generated `X-Correlation-ID` on Trading Lab requests. On an upstream refusal, unsuccessful HTTP response, or transport failure, the bot writes a structured event to its runtime log. The event contains the correlation ID, fixed operation name, elapsed time, and status or exception class.

The bot excludes Telegram initData, identities, trader codes, credentials, raw bodies, and exception messages. Diagnostics do not participate in Trading Lab authorization or change the response sent to the client.

Search the bot runtime logs for `market.trading.upstream.unavailable` and use its `correlation_id` when investigating a 502. Trading Lab can use the same request header for its own diagnostics.

Central 4x-errors delivery requires a collector endpoint that verifies short-lived, scoped 4x-ais workload authorization. The bot sends these diagnostics only to its local runtime log until that endpoint is available.
