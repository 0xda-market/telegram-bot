# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/trading_lab_api"

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
end
