# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/telegram_bot/telegram_api"

class TelegramAPIMenuButtonTest < Minitest::Test
  class RecordingAPI < ZeroXDA::TelegramBot::TelegramAPI
    attr_reader :calls

    def initialize
      @calls = []
      super(token: "123456:test-token")
    end

    private

    def post(method, payload)
      @calls << [method, payload]
      true
    end
  end

  def setup
    @api = RecordingAPI.new
  end

  def test_registers_a_global_https_web_app_menu_button
    @api.set_chat_menu_web_app(
      text: "Market",
      url: "https://0xda-market.nilx.one/bot/webapp/"
    )

    assert_equal(
      [
        "setChatMenuButton",
        {
          menu_button: {
            type: "web_app",
            text: "Market",
            web_app: { url: "https://0xda-market.nilx.one/bot/webapp/" }
          }
        }
      ],
      @api.calls.first
    )
  end

  def test_rejects_non_https_web_app_urls_before_a_telegram_request
    error = assert_raises(ArgumentError) do
      @api.set_chat_menu_web_app(text: "Market", url: "http://localhost:9292/webapp/")
    end

    assert_includes error.message, "HTTPS"
    assert_empty @api.calls
  end

  def test_rejects_an_empty_menu_button_label
    assert_raises(ArgumentError) do
      @api.set_chat_menu_web_app(text: " ", url: "https://example.com/webapp/")
    end

    assert_empty @api.calls
  end
end
