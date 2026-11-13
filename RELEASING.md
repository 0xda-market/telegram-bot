# Releasing 0xda Market Bot

The project uses Semantic Versioning. Stable tags have the form `vMAJOR.MINOR.PATCH`;
for example, release `0.1.0` is tagged `v0.1.0` rather than `release_0.1`.

## Release flow

1. Update `VERSION`, move curated entries from `Unreleased` in `CHANGELOG.md`,
   and add `docs/releases/vX.Y.Z.md` on `master`.
2. Require green tests and verify the development VPS against the matching core
   with the cross-repository `deploy/vps/verify.sh` script from the core release.
3. Promote and verify the matching core version first, including migrations,
   public health and its database recovery boundary.
4. From the exact green master head, run the manual **Publish Market Bot production
   candidate** workflow (GitHub Environment `production`). It validates
   production-only bot credentials, builds and attests an immutable image plus
   its age-encrypted secrets envelope. No deployment occurs.
5. Confirm production Core, the distinct Telegram identity and the edge
   `/bot/*` route are ready, then explicitly run
   `aiaiaiai-org/infra` → **Reconcile deliveries** with
   `workload=market-bot-production`. This contract is `mode: manual`; it is
   excluded from scheduled reconciliation. Inspect that run's health result
   before touching the Telegram webhook or Mini App menu. Production Core must
   already have a healthy delivery; test credentials must never be reused.
6. Register or verify the production Telegram webhook explicitly only after
   `https://0xda-market.nilx.one/bot/health` is healthy. Do not infer
   registration from an infra deploy. Development must never perform this cutover.
7. Verify `/health`, `/bot/health`, `/start`, `/buy`, `/apply_prices`, one
   controlled price update and the production price-digest timer.
8. Run **Prepare GitHub release** with `vX.Y.Z`, or create
   `release-request/vX.Y.Z` from the exact production-branch HEAD. The workflow
   retests the commit, builds the image, creates an annotated tag and saves a
   draft GitHub Release.
9. Review the draft and publish it after the matching core release is public.

Tags are immutable release coordinates: never move or reuse a published tag.

## Rollback

Prefer a revert pull request or forward fix; do not force-push the production
branch. Keep the core and bot compatibility pair together. The VPS deployment
attempts to restart the previous bot release after a failed active refresh, and
the core environment-switch controller attempts to restore the previous pair.

Follow the core `deploy/vps/OPERATIONS.md` runbook for manual recovery. After a
bot rollback, verify `/buy`, `/apply_prices`, `premium_12m`, webhook delivery and
the price-digest timer against the currently active core.
