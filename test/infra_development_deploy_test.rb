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
    gate = @workflow.fetch("jobs").fetch("package").fetch("steps")
      .find { |step| step["name"] == "Require master and successful exact-head CI" }
      .fetch("run")

    assert_includes gate, "refs/heads/master"
    assert_includes gate, 'actions/runs?head_sha=$GITHUB_SHA&per_page=100'
    assert_match(/\.head_sha\s*==\s*\$sha/, gate)
    assert_match(/\.head_branch\s*==\s*"master"/, gate)
    assert_match(/\.path\s*==\s*"\.github\/workflows\/ci\.yml"/, gate)
    assert_match(/\.event\s*==\s*"push"/, gate)
    assert_match(/\.status\s*==\s*"completed"/, gate)
    assert_match(/\.conclusion\s*==\s*"success"/, gate)
    refute_includes gate, "event=push&head_sha=$GITHUB_SHA"

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
    assert_includes @contents, "secrets.TRADING_LAB_TOKEN"
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

  def test_automatic_delivery_publishes_attested_image_and_envelope
    ci = YAML.safe_load(File.read(CI_WORKFLOW), aliases: false)
    job = ci.dig("jobs", "publish-development")
    assert_equal "test", job["needs"]
    assert_equal "github.event_name == 'push' && github.ref == 'refs/heads/master'", job["if"]
    assert_equal "development", job.dig("environment", "name")
    assert_equal({ "contents" => "read", "packages" => "write", "id-token" => "write", "attestations" => "write" }, job["permissions"])
    steps = job.fetch("steps")
    tags = steps.filter_map { |step| step.dig("with", "tags") }
    assert_equal ["${{ env.IMAGE }}:${{ github.sha }}", "${{ env.IMAGE }}:${{ github.sha }}.secrets"], tags
    assert_equal 2, steps.count { |step| step["uses"].to_s.start_with?("actions/attest-build-provenance@") }
    encrypt = steps.find { |step| step["name"] == "Encrypt credentials to the edge-prod-1 recipient" }
    # Must equal the market-bot-test secret allowlist plus producerEnvironment in aiaiaiai-org/infra.
    assert_equal %w[MARKET_API_TOKEN MARKET_API_URL PUBLIC_URL TELEGRAM_BOT_TOKEN TELEGRAM_BOT_USERNAME
                    TELEGRAM_WEBHOOK_SECRET TRADING_LAB_TOKEN], encrypt.fetch("env").keys.sort
    refute_includes File.read(CI_WORKFLOW), "INFRA_DEPLOY_TOKEN"
    job.fetch("steps").each do |step|
      next unless step["run"]
      _out, err, status = Open3.capture3("bash", "-n", stdin_data: step["run"])
      assert status.success?, "#{step.fetch('name')}: #{err}"
    end
  end
end
