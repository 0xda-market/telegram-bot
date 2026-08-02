require_relative "test_helper"
require "zero_x_da/market/telegram_bot/mini_app_entry_point"

class MiniAppEntryPointTest < Minitest::Test
  WEB_APP_URL = "https://market.example/webapp/"

  def setup
    @telegram = FakeTelegramAPI.new
  end

  def test_admin_status_card_exposes_the_configured_mini_app
    bot = build_bot(web_app_url: WEB_APP_URL)

    bot.handle(update("/status", user_id: 99, chat_id: 990))

    card = @telegram.messages.last
    assert_includes card.fetch(:text), "role: admin"
    launch_button = card.dig(:reply_markup, :inline_keyboard, 0, 0)
    assert_equal "🛍️ 0xda-market", launch_button.fetch(:text)
    assert_equal({ url: WEB_APP_URL }, launch_button.fetch(:web_app))
    assert_equal "s:a", card.dig(:reply_markup, :inline_keyboard, 1, 0, :callback_data)
  end

  def test_blank_mini_app_url_preserves_the_status_card
    bot = build_bot(web_app_url: "  ")

    bot.handle(update("/status"))

    rows = @telegram.messages.last.dig(:reply_markup, :inline_keyboard)
    assert_equal 1, rows.length
    assert_equal "s:a", rows.dig(0, 0, :callback_data)
  end

  private

  def build_bot(web_app_url:)
    ZeroXDA::Market::TelegramBot::Bot.new(
      market_api: FakeMarketAPI.new,
      telegram_api: @telegram,
      web_app_url: web_app_url,
      status_message_ttl: 0
    )
  end

  def update(text, user_id: 77, chat_id: 770)
    {
      "message" => {
        "message_id" => 10,
        "text" => text,
        "from" => {
          "id" => user_id,
          "username" => "zero",
          "first_name" => "Sasha",
          "language_code" => "uk"
        },
        "chat" => { "id" => chat_id, "type" => "private" }
      }
    }
  end
end
