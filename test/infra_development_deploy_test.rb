# frozen_string_literal: true

require_relative "test_helper"
require "yaml"
require "open3"

class InfraDevelopmentDeployTest < Minitest::Test
  WORKFLOW = File.expand_path("../.github/workflows/deploy-vps.yml", __dir__)
  CI_WORKFLOW = File.expand_path("../.github/workflows/ci.yml", __dir__)

  def setup
    @contents = File.read(WORKFLOW)
    @workflow = YAML.safe_load(@contents, aliases: false)
  end

  def test_manual_development_deploy_uses_only_infra
    assert_includes @contents, "workflow_dispatch:"
    refute_includes @contents, "repository_dispatch:\n"
    assert_includes @contents, "refs/heads/master"
    assert_includes @contents, "market-bot-test"
    assert_includes @contents, "aiaiaiai-org/infra"
    assert_includes @contents, "age --armor --recipient"
    assert_includes @contents, "deploy-workload"
    assert_includes @contents, "issue-workload-recipient"
    assert_includes @contents, "secrets_age"
    refute_match(/SSH_(HOST|USER|PRIVATE_KEY|PORT|DEPLOYMENT_PATH)/, @contents)
    refute_includes @contents, "ssh -p "
    refute_includes @contents, "scp "
  end

  def test_release_is_digest_pinned_and_exact_head_ci_gated
    assert_includes @contents, "event=push&head_sha=$GITHUB_SHA"
    assert_includes @contents, "docker/build-push-action@v6"
    assert_includes @contents, "ghcr.io/0xda-market/telegram-bot@$DIGEST"
    assert_includes @contents, "sha256:[0-9a-f]{64}"
    assert_includes File.read(CI_WORKFLOW), "branches: [master]"
  end

  def test_credentials_are_scoped_to_development_and_encrypted
    assert_equal "development", @workflow.dig("jobs", "request", "environment", "name")
    assert_includes @contents, "secrets.TELEGRAM_BOT_TOKEN"
    assert_includes @contents, "secrets.TELEGRAM_WEBHOOK_SECRET"
    assert_includes @contents, "secrets.MARKET_API_TOKEN"
    assert_includes @contents, "vars.TELEGRAM_BOT_USERNAME"
    assert_includes @contents, "vars.MARKET_API_URL"
    assert_includes @contents, "vars.PUBLIC_URL"
    assert_includes @contents, "secrets.INFRA_DEPLOY_TOKEN"
    refute_includes @contents, "GHCR_PULL_TOKEN"
    refute_includes @contents, "GHCR_PULL_USER"
    assert_includes @contents, "http://market-api-development:10000"
    assert_includes @contents, "https://0xda-market.nilx.one/bot-test"
    refute_includes @contents, "MARKET_POSTGRES_PASSWORD"
  end

  def test_all_shell_steps_are_valid_bash
    @workflow.fetch("jobs").each_value do |job|
      job.fetch("steps").each do |step|
        next unless step["run"]
        _out, err, status = Open3.capture3("bash", "-n", stdin_data: step["run"])
        assert status.success?, "#{step.fetch('name')}: #{err}"
      end
    end
  end
end
