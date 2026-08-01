require_relative "test_helper"
require "zero_x_da/market/telegram_bot/bot"
require "zero_x_da/market/telegram_bot/persistent_runtime"

class PersistentRuntimeTest < Minitest::Test
  def test_slow_command_does_not_claim_that_the_persistent_server_is_starting
    market = Class.new(FakeMarketAPI) do
      def authenticate_telegram(**arguments)
        sleep 0.03
        super
      end
    end.new
    telegram = FakeTelegramAPI.new
    bot = ZeroXDA::Market::TelegramBot::Bot.new(
      market_api: market,
      telegram_api: telegram,
      server_start_notice_delay: 0.005,
      status_message_ttl: 0
    )
    bot.extend(ZeroXDA::Market::TelegramBot::PersistentRuntime)

    bot.handle(update("/start"))

    refute telegram.messages.any? { |message| message.fetch(:text) == "Сервер запускається…" }
    assert_includes telegram.messages.last.fetch(:text), "авторизація успішна"
  end

  private

  def update(text)
    {
      "message" => {
        "message_id" => 10,
        "text" => text,
        "from" => {
          "id" => 77,
          "username" => "zero",
          "first_name" => "Sasha",
          "language_code" => "uk"
        },
        "chat" => { "id" => 770, "type" => "private" }
      }
    }
  end
end
