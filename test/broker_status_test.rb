require_relative "test_helper"
require "zero_x_da/market/telegram_bot/bot"

class BrokerStatusTest < Minitest::Test
  class BrokerMarketAPI < FakeMarketAPI
    def authenticate_telegram(user:, chat:)
      resource = super
      resource.fetch("attributes")["role"] = "broker"
      resource
    end
  end

  def test_status_renders_the_persisted_broker_role
    market = BrokerMarketAPI.new
    telegram = FakeTelegramAPI.new
    bot = ZeroXDA::Market::TelegramBot::Bot.new(
      market_api: market,
      telegram_api: telegram,
      status_message_ttl: 0
    )

    bot.handle(
      "message" => {
        "message_id" => 10,
        "text" => "/status",
        "from" => {
          "id" => 77,
          "username" => "pojesus",
          "first_name" => "Sasha",
          "language_code" => "uk"
        },
        "chat" => { "id" => 770, "type" => "private" }
      }
    )

    assert_includes telegram.messages.last.fetch(:text), "role: broker"
    refute_includes telegram.messages.last.fetch(:text), "role: client"
  end
end
