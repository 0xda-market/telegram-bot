# Persistent status cards

Account and service status are rendered as long-lived Telegram messages rather than short-lived command responses.

## Interaction contract

```text
/status
  -> account status card
  -> s:a refresh callback
  -> edit the same Telegram message

/servers
  -> administrator service status card
  -> s:s refresh callback
  -> edit the same Telegram message
```

The callback contains only the card type. The bot authenticates the current callback sender, reloads current state from core, and edits the message that carried the button. No message ID, session, timer, or status snapshot is stored in process memory or PostgreSQL.

The incoming `/status` or `/servers` command may still be deleted after the existing short cleanup delay. The resulting card is not scheduled for deletion.

## Authorization

Account refresh authenticates the Telegram identity and updates its private command menu before rendering the latest persisted role and status.

Service refresh repeats the same authentication and additionally requires the current persisted `admin` role before requesting core health. A stale card therefore cannot preserve revoked administrator access.

## Failure behavior

Telegram treats an edit with unchanged text and markup as `message is not modified`; the Telegram adapter already normalizes that response to a successful no-op. Callback queries are answered after rendering so the Telegram loading indicator is cleared.
