# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "test_helper"
require "yaml"
require "open3"

class ProductionSeedsPublicationTest < Minitest::Test
  def preflight(values)
    source = YAML.safe_load(File.read(File.expand_path("../.github/workflows/publish-production.yml", __dir__)))
    step = source.fetch("jobs").fetch("publish").fetch("steps").find { |item| item["name"] == "Validate isolated production configuration" }
    # Execute the actual publication validation, ending before any network/write.
    script = step.fetch("run").split("# A configured username", 2).first
    expected = %w[PARTNER_LOOKUP_TOKEN CHANNEL_ASSERTION_SECRET]
    expected.each { |key| assert_equal "${{ secrets.#{key} }}", step.fetch("env").fetch(key) }
    Open3.capture3(valid.merge(values), "bash", "-c", script)
  end

  def test_valid_distinct_keys_pass
    _out, err, status = preflight({})
    assert status.success?, err
  end

  def test_missing_short_multiline_and_reused_keys_fail_without_disclosing_values
    [{ "PARTNER_LOOKUP_TOKEN" => "" }, { "CHANNEL_ASSERTION_SECRET" => "short-private-value" },
     { "PARTNER_LOOKUP_TOKEN" => "private-value\ninjected" },
     { "CHANNEL_ASSERTION_SECRET" => "p" * 40 }].each do |values|
      out, err, status = preflight(values)
      refute status.success?
      refute_includes out + err, "short-private-value"
      refute_includes out + err, "private-value"
      refute_includes out + err, "p" * 40
    end
  end

  def valid
    { "TELEGRAM_BOT_TOKEN" => "test-token", "TELEGRAM_WEBHOOK_SECRET" => "test_secret",
      "MARKET_API_TOKEN" => "test-token", "TRADING_LAB_TOKEN" => "test-token",
      "PARTNER_LOOKUP_TOKEN" => "p" * 40, "CHANNEL_ASSERTION_SECRET" => "c" * 40,
      "TELEGRAM_BOT_USERNAME" => "production_market_bot", "PUBLIC_URL" => "https://0xda-market.nilx.one/bot",
      "MARKET_API_URL" => "http://market-api-production:1927" }
  end
end
