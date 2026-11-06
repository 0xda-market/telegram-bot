# frozen_string_literal: true

require_relative "test_helper"
require "yaml"
require "open3"

class InfraDevelopmentDeployTest < Minitest::Test
  CI_WORKFLOW = File.expand_path("../.github/workflows/ci.yml", __dir__)

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
    refute File.exist?(File.expand_path("../.github/workflows/deploy-vps.yml", __dir__)), "legacy dispatch deploy must stay removed"
    assert_includes File.read(CI_WORKFLOW), "branches: [master]"
    contents = File.read(CI_WORKFLOW)
    assert_includes contents, "https://0xda-market.nilx.one/bot-test"
    assert_includes contents, "http://market-api-development:10000"
    refute_match(/SSH_(HOST|USER|PRIVATE_KEY|PORT)/, contents)
    refute_includes contents, "MARKET_POSTGRES_PASSWORD"
    job.fetch("steps").each do |step|
      next unless step["run"]
      _out, err, status = Open3.capture3("bash", "-n", stdin_data: step["run"])
      assert status.success?, "#{step.fetch('name')}: #{err}"
    end
  end
end
