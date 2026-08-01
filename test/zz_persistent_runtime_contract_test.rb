# frozen_string_literal: true

require_relative "bot_test"

class BotTest
  def test_reports_a_slow_market_start_and_sends_the_result_later
    slow_market = Class.new(FakeMarketAPI) do
      def authenticate_telegram(**arguments)
        sleep 0.03
        super
      end
    end.new
    bot = ZeroXDA::Market::TelegramBot::Bot.new(
      market_api: slow_market,
      telegram_api: @telegram,
      server_start_notice_delay: 0.005
    )

    bot.handle(update("/start"))

    assert_equal 1, @telegram.messages.length
    refute_equal "Сервер запускається…", @telegram.messages.first.fetch(:text)
    assert_includes @telegram.messages.first.fetch(:text), "авторизація успішна"
  end
end
