# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/trading_lab_api"
require "socket"

class TradingLabAPITest < Minitest::Test
  def build(origin, token = "fake-replay-token")
    ZeroXDA::Market::TelegramBot::TradingLabAPI.new(origin: origin, token: token)
  end

  def test_explicit_infra_private_host_and_port_are_allowed
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("http://market-trading-lab:1927")
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("http://localhost:9293")
    assert_instance_of ZeroXDA::Market::TelegramBot::TradingLabAPI,
                       build("https://trading-lab.example.test")
  end

  def test_arbitrary_cleartext_origins_are_refused
    %w[http://market-trading-lab:1928 http://market-trading-lab:1927/other
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
  def with_lab(status, body)
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
    yield build("http://127.0.0.1:#{server.addr[1]}"), seen
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

  def test_leaders_options_are_checked_before_transport
    client = build("http://market-trading-lab:1927")
    assert_raises(ArgumentError) { client.leaders(options: "sort=pnl") }
    assert_raises(ArgumentError) { client.leaders(options: { "api_key" => "x" }) }
    assert_raises(ArgumentError) { client.leaders(options: { "sort" => "pnl&limit=1" }) }
    assert_raises(ArgumentError) { client.leaders(options: { "sort" => "a" * 33 }) }
  end
end
