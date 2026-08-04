# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/broker_order_notifier"

class BrokerOrderNotifierTest < Minitest::Test
  class Market
    attr_reader :acknowledgements

    def initialize
      @acknowledgements = []
    end

    def active_users
      [{
        "id" => "client-1",
        "attributes" => { "telegram_chat_id" => "1001", "language_code" => "uk" }
      }]
    end

    def acknowledge_broker_order_notification(**attributes)
      @acknowledgements << attributes
    end
  end

  def test_delivers_pending_transition_acknowledges_it_and_strips_private_metadata
    market = Market.new
    telegram = FakeTelegramAPI.new
    notifier = ZeroXDA::Market::TelegramBot::BrokerOrderNotifier.new(
      market_api: market, telegram_api: telegram
    )
    resource = {
      "id" => "order-1",
      "attributes" => { "product_name" => "Premium 3m", "quantity" => "1" },
      "meta" => {
        "notification_event" => "broker_order_accepted",
        "notification_recipient_user_id" => "client-1"
      }
    }

    public_resource = notifier.deliver(resource, actor_user_id: "broker-1")

    assert_equal "1001", telegram.messages.first.fetch(:chat_id).to_s
    assert_includes telegram.messages.first.fetch(:text), "Broker погодився"
    assert_equal({
      actor_user_id: "broker-1", order_id: "order-1", event: "broker_order_accepted"
    }, market.acknowledgements.first)
    refute public_resource.key?("meta")
  end

  def test_ignores_a_resource_without_a_pending_notification
    market = Market.new
    telegram = FakeTelegramAPI.new
    notifier = ZeroXDA::Market::TelegramBot::BrokerOrderNotifier.new(
      market_api: market, telegram_api: telegram
    )

    notifier.deliver(
      { "id" => "order-1", "attributes" => {}, "meta" => {} },
      actor_user_id: "broker-1"
    )

    assert_empty telegram.messages
    assert_empty market.acknowledgements
  end
end
