#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -f .env ]]; then
  echo "deploy/vps/.env is missing" >&2
  exit 1
fi

deploy_mode="${DEPLOY_MODE:-activate}"
deploy_environment="$(sed -n 's/^DEPLOY_ENV=//p' .env | tail -n 1)"
edge_network="${MARKET_EDGE_NETWORK:-nilx-edge}"
release_sha="${RELEASE_SHA:-}"
core_env="/opt/0xda-market/environments/${deploy_environment}/shared/.env"

if [[ "$edge_network" != "nilx-edge" ]]; then
  echo "MARKET_EDGE_NETWORK must be nilx-edge" >&2
  exit 1
fi

if [[ -z "$release_sha" ]]; then
  echo "RELEASE_SHA is required" >&2
  exit 1
fi

case "$deploy_mode" in
  stage|activate) ;;
  *)
    echo "Unsupported DEPLOY_MODE: $deploy_mode" >&2
    exit 1
    ;;
esac

case "$deploy_environment" in
  development|production) ;;
  *)
    echo "DEPLOY_ENV must be development or production" >&2
    exit 1
    ;;
esac

if [[ ! -f "$core_env" ]]; then
  echo "Core runtime file is missing: $core_env" >&2
  exit 1
fi

core_api_token="$(sed -n 's/^PUBLIC_API_TOKEN=//p' "$core_env" | tail -n 1)"
if [[ -z "$core_api_token" ]]; then
  echo "PUBLIC_API_TOKEN is missing from the core runtime" >&2
  exit 1
fi

python3 - "$core_api_token" <<'PY'
from pathlib import Path
import os
import sys
import tempfile

path = Path('.env')
token = sys.argv[1]
lines = path.read_text().splitlines()
updated = []
replaced = False
for line in lines:
    if line.startswith('MARKET_API_TOKEN='):
        updated.append(f'MARKET_API_TOKEN={token}')
        replaced = True
    else:
        updated.append(line)
if not replaced:
    updated.append(f'MARKET_API_TOKEN={token}')

fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.env.', text=True)
try:
    with os.fdopen(fd, 'w') as handle:
        handle.write('\n'.join(updated) + '\n')
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
unset core_api_token

echo "Core API credential synchronized for $deploy_environment"

if ! docker network inspect "$edge_network" >/dev/null 2>&1; then
  docker network create "$edge_network" >/dev/null
fi

export RELEASE_SHA="$release_sha"
docker compose config --quiet
docker compose build --pull bot

if [[ "$deploy_mode" == "stage" ]]; then
  echo "0xda-market bot $deploy_environment release $release_sha staged"
  exit 0
fi

docker compose up -d --wait bot

curl --fail --silent --show-error \
  --retry 10 --retry-delay 3 --retry-connrefused \
  http://127.0.0.1:10001/health >/dev/null

container_id="$(docker compose ps -q bot)"
active_sha="$(docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$container_id")"
if [[ "$active_sha" != "$release_sha" ]]; then
  echo "Active bot release mismatch: expected $release_sha, got $active_sha" >&2
  exit 1
fi

expected_webhook="$(sed -n 's/^PUBLIC_URL=//p' .env | tail -n 1)"
expected_webhook="${expected_webhook%/}/telegram/webhook"
actual_webhook="$(docker compose exec -T bot bundle exec ruby -Ilib -rzero_x_da/market/telegram_bot/telegram_api -e '
  api = ZeroXDA::Market::TelegramBot::TelegramAPI.new(token: ENV.fetch("TELEGRAM_BOT_TOKEN"))
  identity = api.get_me
  abort "Telegram getMe returned no bot identity" unless identity["is_bot"]
  puts "Telegram identity verified: @#{identity["username"]}"
  public_url = ENV.fetch("PUBLIC_URL").delete_suffix("/")
  webhook_url = "#{public_url}/telegram/webhook"
  api.set_webhook(url: webhook_url, secret_token: ENV.fetch("TELEGRAM_WEBHOOK_SECRET"))
  puts api.get_webhook_info.fetch("url")
' | tail -n 1)"

if [[ "$actual_webhook" != "$expected_webhook" ]]; then
  echo "Telegram webhook mismatch after reconciliation: expected $expected_webhook, got $actual_webhook" >&2
  exit 1
fi

docker compose exec -T bot bundle exec ruby -Ilib \
  -rzero_x_da/market/telegram_bot/market_api \
  -ruri -e '
    base_url = ENV.fetch("MARKET_API_URL")
    uri = URI(base_url)
    puts "Core target: #{uri.scheme}://#{uri.host}#{uri.port && ![80, 443].include?(uri.port) ? ":#{uri.port}" : ""}"
    api = ZeroXDA::Market::TelegramBot::MarketAPI.new(
      base_url: base_url,
      token: ENV.fetch("MARKET_API_TOKEN")
    )
    health = api.health
    abort "Core health probe failed" unless health.is_a?(Hash)
    puts "Core health verified"
    products = api.products(locale: "en_US")
    abort "Core authenticated probe returned invalid data" unless products.is_a?(Array)
    puts "Core API credential verified"
  '

echo "0xda-market bot $deploy_environment release $release_sha is healthy"
echo "Telegram webhook reconciled and verified: $actual_webhook"
