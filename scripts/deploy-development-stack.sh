#!/usr/bin/env bash
# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
set -Eeuo pipefail

# One explicit workflow_dispatch initiates the stack. Actual activations are
# delegated to each producer's existing manual deploy workflow, then to infra.
[[ "${GITHUB_REF:-}" == "refs/heads/master" ]] || {
  echo "::error::Stack deployment is restricted to master." >&2
  exit 1
}
[[ -n "${GH_TOKEN:-}" ]] || {
  echo "::error::Missing MARKET_ORCHESTRATION_TOKEN (Actions read/write on the three producers)." >&2
  exit 1
}
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ ]] || exit 1
[[ "${GITHUB_RUN_ATTEMPT:-1}" =~ ^[0-9]+$ ]] || exit 1
request_id="stack-$GITHUB_RUN_ID-${GITHUB_RUN_ATTEMPT:-1}"

core_repo=0xda-market/core
web_repo=0xda-market/webapp-core
bot_repo=0xda-market/telegram-bot

master_sha() {
  gh api --method GET "repos/$1/commits/master" --jq '.sha'
}

verify_ci() {
  local repo="$1" sha="$2" runs
  runs="$(gh api --method GET "repos/$repo/actions/runs?head_sha=$sha&per_page=100")"
  jq -e --arg sha "$sha" '
    [.workflow_runs[] | select(.head_sha == $sha
      and .head_branch == "master"
      and .path == ".github/workflows/ci.yml"
      and .event == "push"
      and .status == "completed"
      and .conclusion == "success")] | length > 0
  ' <<<"$runs" >/dev/null || {
    echo "::error::Missing green exact-head push Full CI in $repo ($sha)." >&2
    exit 1
  }
}

dispatch_and_await() {
  local repo="$1" workflow="$2" expected="$3" title="$4"
  local sha response match run_id status conclusion
  sha="$(master_sha "$repo")"
  [[ "$sha" == "$expected" ]] || {
    echo "::error::$repo/master advanced during the stack release. Start a new reviewed release." >&2
    exit 1
  }

  jq -nc --arg id "$request_id"     '{ref: "master", inputs: {request_id: $id}}' |
    gh api --method POST "repos/$repo/actions/workflows/$workflow/dispatches" --input -

  for attempt in $(seq 1 480); do
    response="$(gh api --method GET "repos/$repo/actions/runs?head_sha=$expected&per_page=100")"
    match="$(jq -c --arg title "$title" --arg sha "$expected" '
      [.workflow_runs[] | select(.display_title == $title
        and .head_sha == $sha
        and .head_branch == "master"
        and .event == "workflow_dispatch"
        and .path == ".github/workflows/'"$workflow"'")] | sort_by(.id) | last // empty
    ' <<<"$response")"
    if [[ -n "$match" ]]; then
      run_id="$(jq -r .id <<<"$match")"
      status="$(jq -r .status <<<"$match")"
      conclusion="$(jq -r '.conclusion // ""' <<<"$match")"
      if [[ "$status" == completed ]]; then
        {
          echo "- $repo: https://github.com/$repo/actions/runs/$run_id"
          echo "  - revision: $expected"
          echo "  - result: $conclusion"
        } >> "$GITHUB_STEP_SUMMARY"
        [[ "$conclusion" == success ]] || {
          echo "::error::$repo deployment failed ($run_id)." >&2
          exit 1
        }
        return 0
      fi
    fi
    sleep 15
  done
  echo "::error::Timed out awaiting $repo deployment." >&2
  exit 1
}

# Preflight all three producers BEFORE any activation. No partial release due
# to a known failed CI or a stale shared UI pin.
core_sha="$(master_sha "$core_repo")"
web_sha="$(master_sha "$web_repo")"
bot_sha="$(master_sha "$bot_repo")"
for sha in "$core_sha" "$web_sha" "$bot_sha"; do
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "::error::Invalid master commit SHA"; exit 1; }
done
[[ "$bot_sha" == "$GITHUB_SHA" ]] || {
  echo "::error::Run the current telegram-bot master, not a stale revision." >&2
  exit 1
}

pinned_web_sha="$(sed -n 's/^const WEBAPP_CORE_REVISION = "\([0-9a-f]*\)";$/\1/p' webapp/app.js)"
[[ "$pinned_web_sha" =~ ^[0-9a-f]{40}$ && "$pinned_web_sha" == "$web_sha" ]] || {
  echo "::error::Telegram Mini App pins $pinned_web_sha, but webapp-core master is $web_sha. Update the reviewed bot pin before deployment." >&2
  exit 1
}

verify_ci "$core_repo" "$core_sha"
verify_ci "$web_repo" "$web_sha"
verify_ci "$bot_repo" "$bot_sha"

{
  echo "### Market development stack"
  echo "- Request: $request_id"
  echo "- Core revision: $core_sha"
  echo "- WebApp revision (also pinned by Telegram Mini App): $web_sha"
  echo "- Bot revision: $bot_sha"
} >> "$GITHUB_STEP_SUMMARY"

# Core includes API migrations and workers; it must finish before webapp/bot.
dispatch_and_await "$core_repo" "deploy-vps.yml" "$core_sha" "Deploy Market Core $request_id"
dispatch_and_await "$web_repo" "deploy-development.yml" "$web_sha" "Deploy Market WebApp $request_id"
dispatch_and_await "$bot_repo" "deploy-vps.yml" "$bot_sha" "Deploy Market Bot $request_id"

echo "All three producer workflows and infra activations finished successfully." >> "$GITHUB_STEP_SUMMARY"
