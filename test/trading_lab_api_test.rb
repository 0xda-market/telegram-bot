# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require_relative "test_helper"
require "minitest/mock"
require "zero_x_da/market/telegram_bot/trading_lab_api"
require "socket"
require "stringio"

class TradingLabAPITest < Minitest::Test
  def build(origin, token = "fake-replay-token", logger: nil)
    ZeroXDA::Market::TelegramBot::TradingLabAPI.new(origin: origin, token: token, logger: logger)
  end

  def test_explicit_infra_private_host_and_port_are_allowed
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("http://market-trading-lab:1927")
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("http://market-trading-lab-development:1703")
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("http://localhost:9293")
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("https://trading-lab.example.test")
  end

  def test_arbitrary_cleartext_origins_are_refused
    %w[http://market-trading-lab:1928 http://market-trading-lab:1927/other
       http://market-trading-lab:1703 http://market-trading-lab-development:1927
       http://market-trading-lab-development:1703/other
       http://evil-market-trading-lab:1927 http://127.0.0.2:1927
       http://api.example.test:1927].each do |origin|
      assert_raises(ArgumentError, origin) { build(origin) }
    end
  end

  def test_origin_may_not_contain_userinfo_query_or_fragment
    %w[https://user@trading.example.test https://trading.example.test/?x=1
       https://trading.example.test/#fragment].each do |origin|
      assert_raises(ArgumentError, origin) { build(origin) }
    end
    assert_raises(ArgumentError) { build("http://market-trading-lab:1927", "") }
  end

  def test_payload_validation_before_transport
    client = build("http://market-trading-lab:1927")
    assert_raises(ArgumentError) { client.replay(events: "not an array") }
    assert_raises(ArgumentError) { client.replay(events: [{}] * 501) }
    assert_raises(ArgumentError) { client.replay(events: [], options: "not an object") }
  end

  # Serves one HTTP response on 127.0.0.1 and records the raw request head.
  def with_lab(status, body, logger: nil)
    server = TCPServer.new("127.0.0.1", 0)
    seen = []
    thread = Thread.new do
      client = server.accept
      while (line = client.gets) && line != "\r\n"
        seen << line.chomp
      end
      client.write "HTTP/1.1 #{status} X\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      client.close
    end
    yield build("http://127.0.0.1:#{server.addr[1]}", logger: logger), seen
  ensure
    thread&.join(2)
    server&.close
  end

  def test_leaders_forwards_sorted_filters_with_service_token
    body = JSON.generate(status: "ok", data: { "traders" => [], "data_version" => "20261105150001" })
    with_lab(200, body) do |client, seen|
      data = client.leaders(options: { "sort" => "pnl_ratio", "limit" => "20", min_lead_days: "90" })
      assert_equal "20261105150001", data["data_version"]
      assert_equal "GET /v1/leaders/okx?limit=20&min_lead_days=90&sort=pnl_ratio HTTP/1.1", seen.first
      assert(seen.any? { |line| line.casecmp?("authorization: Bearer fake-replay-token") })
    end
  end

  def test_leaders_maps_lab_errors
    with_lab(422, JSON.generate(status: "error", error: "invalid_request", message: "limit must be between 1 and 20")) do |client, _|
      error = assert_raises(ArgumentError) { client.leaders(options: { "limit" => "50" }) }
      assert_equal "limit must be between 1 and 20", error.message
    end
    with_lab(422, JSON.generate(status: "error", message: "<script>\n#{'x' * 200}")) do |client, _|
      error = assert_raises(ArgumentError) { client.leaders(options: { "sort" => "luck" }) }
      assert_equal "invalid leaderboard request", error.message
    end
    with_lab(503, JSON.generate(status: "error", error: "upstream_rate_limited")) do |client, _|
      assert_raises(ZeroXDA::Market::TelegramBot::TradingLabAPI::Error) { client.leaders }
    end
  end

  def test_copy_replay_exposes_safe_quote_budget_error_instead_of_generic_validation
    with_lab(422, JSON.generate(status: "error", error: "invalid_request",
                                message: "too many positions to quote in one replay; lower max_positions")) do |client, _|
      error = assert_raises(ArgumentError) { client.copy_replay(unique_code: "9A8534AB09862774") }
      assert_equal "too many positions to quote in one replay; lower max_positions", error.message
    end
  end

  def test_copy_replay_reports_502_with_correlated_safe_metadata
    logger = StringIO.new
    with_lab(502, JSON.generate(status: "error", error: "upstream_unavailable"), logger: logger) do |client, seen|
      assert_raises(ZeroXDA::Market::TelegramBot::TradingLabAPI::Error) do
        client.copy_replay(unique_code: "9A8534AB09862774")
      end
      event = JSON.parse(logger.string, symbolize_names: true)
      assert_equal "market.trading.upstream.unavailable", event[:error_id]
      assert_equal 502, event.dig(:context, :upstream_status)
      assert_equal "copy_replay", event.dig(:context, :operation)
      assert_match(/\A[0-9a-f-]{36}\z/, event[:correlation_id])
      assert(seen.any? { |line| line.casecmp?("x-correlation-id: #{event.fetch(:correlation_id)}") })
      refute_includes JSON.generate(event), "9A8534AB09862774"
      refute_includes JSON.generate(event), "fake-replay-token"
    end
  end

  def test_unavailable_errors_carry_a_stable_code_and_no_internal_details
    error_class = ZeroXDA::Market::TelegramBot::TradingLabAPI::Error
    with_lab(502, JSON.generate(status: "error", error: "upstream_unavailable")) do |client, _|
      error = assert_raises(error_class) { client.copy_replay(unique_code: "9A8534AB09862774") }
      assert_equal "trading_lab_unavailable", error.code
      assert_equal "Trading Lab copy replay is unavailable", error.message
    end
    with_lab(200, "not json") do |client, _|
      error = assert_raises(error_class) { client.leaders }
      assert_equal "trading_lab_unavailable", error.code
      refute_match(/JSON|HTTP|Net::/, error.message)
    end
  end

  def test_job_endpoints_report_outages_and_timeouts_with_codes_and_no_internals
    error_class = ZeroXDA::Market::TelegramBot::TradingLabAPI::Error
    id = "a" * 32
    with_lab(502, JSON.generate(status: "error", error: "upstream_unavailable")) do |client, _|
      error = assert_raises(error_class) { client.start_copy_replay(unique_code: "9A8534AB09862774", owner: "internal-owner") }
      assert_equal ["trading_lab_unavailable", "Trading Lab copy job submit is unavailable"], [error.code, error.message]
    end
    client = build("http://127.0.0.1:9")
    Net::HTTP.stub(:start, ->(*, **, &_block) { raise Net::ReadTimeout }) do
      error = assert_raises(error_class) { client.copy_replay_job(job_id: id, owner: "internal-owner") }
      assert_equal ["trading_lab_timeout", "Trading Lab copy job status did not respond in time"], [error.code, error.message]
    end
    with_lab(503, JSON.generate(status: "error", error: "copy_jobs_busy")) do |busy, _|
      error = assert_raises(ZeroXDA::Market::TelegramBot::TradingLabAPI::JobError) do
        busy.start_copy_replay(unique_code: "9A8534AB09862774", owner: "internal-owner")
      end
      assert_equal [503, "copy_jobs_busy", "copy_jobs_busy"], [error.status, error.code, error.message]
    end
  end

  def test_a_read_timeout_is_reported_as_a_timeout_not_as_an_outage
    error_class = ZeroXDA::Market::TelegramBot::TradingLabAPI::Error
    logger = StringIO.new
    client = build("http://127.0.0.1:9", logger: logger)
    [Net::ReadTimeout, Net::OpenTimeout].each do |timeout|
      Net::HTTP.stub(:start, ->(*, **, &_block) { raise timeout }) do
        error = assert_raises(error_class) { client.copy_replay(unique_code: "9A8534AB09862774") }
        assert_equal "trading_lab_timeout", error.code
        assert_equal "Trading Lab copy replay did not respond in time", error.message
      end
    end
    assert_equal "ReadTimeout", JSON.parse(logger.string.lines.first, symbolize_names: true).dig(:context, :exception_type)
  end

  def test_copy_replay_posts_code_and_options_with_service_token
    body = JSON.generate(status: "ok", data: { "unique_code" => "9A8534AB09862774", "copied" => 3 })
    with_lab(200, body) do |client, seen|
      data = client.copy_replay(unique_code: "9A8534AB09862774", options: { "trade_notional" => "50" })
      assert_equal 3, data["copied"]
      assert_equal "POST /v1/paper/copy-replays HTTP/1.1", seen.first
      assert(seen.any? { |line| line.casecmp?("authorization: Bearer fake-replay-token") })
    end
    client = build("http://market-trading-lab:1927")
    assert_raises(ArgumentError) { client.copy_replay(unique_code: "../x") }
    assert_raises(ArgumentError) { client.copy_replay(unique_code: "9A8534AB09862774", options: "x") }
    assert_raises(ArgumentError) { client.copy_replay(unique_code: "9A8534AB09862774", options: { "x" => "y" * 5000 }) }
  end

  def test_async_copy_replay_uses_opaque_owner_and_accepts_202
    id = "a" * 32
    owner = OpenSSL::HMAC.hexdigest("SHA256", "fake-replay-token", "copy-replay-owner:v1:internal-owner")
    with_lab(202, JSON.generate(status: "ok", data: { job_id: id, state: "queued" })) do |client, seen|
      assert_equal id, client.start_copy_replay(unique_code: "9A8534AB09862774", owner: "internal-owner").fetch("job_id")
      assert_equal "POST /v1/paper/copy-replay-jobs HTTP/1.1", seen.first
      assert(seen.any? { |line| line.casecmp?("x-trading-replay-owner: #{owner}") })
      refute_includes seen.join, "internal-owner"
    end
    with_lab(200, JSON.generate(status: "ok", data: { job_id: id, state: "running" })) do |client, seen|
      assert_equal "running", client.copy_replay_job(job_id: id, owner: "internal-owner").fetch("state")
      assert_equal "GET /v1/paper/copy-replay-jobs/#{id} HTTP/1.1", seen.first
      assert(seen.any? { |line| line.casecmp?("x-trading-replay-owner: #{owner}") })
    end
    with_lab(404, JSON.generate(status: "error", error: "copy_job_not_found")) do |client, _|
      error = assert_raises(ZeroXDA::Market::TelegramBot::TradingLabAPI::JobError) { client.copy_replay_job(job_id: id, owner: "internal-owner") }
      assert_equal [404, "copy_job_not_found"], [error.status, error.code]
    end
  end

  def test_leaders_options_are_checked_before_transport
    client = build("http://market-trading-lab:1927")
    assert_raises(ArgumentError) { client.leaders(options: "sort=pnl") }
    assert_raises(ArgumentError) { client.leaders(options: { "api_key" => "x" }) }
    assert_raises(ArgumentError) { client.leaders(options: { "sort" => "pnl&limit=1" }) }
    assert_raises(ArgumentError) { client.leaders(options: { "sort" => "a" * 33 }) }
  end
end
