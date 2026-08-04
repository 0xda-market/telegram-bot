# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/broker_order_notifier"

class BrokerOrderNotifierTest < Minitest::Test
  class Market
    def active_users
      [{
        "id" => "client-1",
        "attributes" => {
          "telegram_chat_id" => "1001",
          "language_code" => "uk"
        }
      }]
    end
  end

  def test_delivers_changed_transition_and_strips_private_metadata
    telegram = FakeTelegramAPI.new
    notifier = ZeroXDA::Market::TelegramBot::BrokerOrderNotifier.new(
      market_api: Market.new,
      telegram_api: telegram
    )
    resource = {
      "id" => "order-1",
      "attributes" => { "product_name" => "Premium 3m", "quantity" => "1" },
      "meta" => {
        "changed" => true,
        "notification_event" => "broker_order_accepted",
        "notification_recipient_user_id" => "client-1"
      }
    }

    public_resource = notifier.deliver(resource)

    assert_equal "1001", telegram.messages.first.fetch(:chat_id).to_s
    assert_includes telegram.messages.first.fetch(:text), "Broker погодився"
    refute public_resource.key?("meta")
  end

  def test_does_not_repeat_an_unchanged_transition
    telegram = FakeTelegramAPI.new
    notifier = ZeroXDA::Market::TelegramBot::BrokerOrderNotifier.new(
      market_api: Market.new,
      telegram_api: telegram
    )

    notifier.deliver(
      "attributes" => { "product_name" => "Premium 3m", "quantity" => "1" },
      "meta" => { "changed" => false }
    )

    assert_empty telegram.messages
  end
end
