# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/telegram_recipient_picker"

class TelegramRecipientPickerTest < Minitest::Test
  class Telegram
    attr_reader :requests

    def initialize
      @requests = []
    end

    def save_prepared_keyboard_button(user_id:, button:)
      @requests << { user_id: user_id, button: button }
      { "id" => "prepared-1" }
    end
  end

  def setup
    @telegram = Telegram.new
    @now = Time.utc(2026, 8, 8, 7, 0, 0)
    @picker = ZeroXDA::Market::TelegramBot::TelegramRecipientPicker.new(
      telegram_api: @telegram,
      clock: -> { @now },
      ttl_seconds: 60
    )
  end

  def test_prepares_single_regular_user_request_and_captures_shared_username
    prepared = @picker.prepare(requester_id: 77)
    request = @telegram.requests.fetch(0)
    request_id = request.dig(:button, :request_users, :request_id)

    assert_equal 77, request.fetch(:user_id)
    assert_equal false, request.dig(:button, :request_users, :user_is_bot)
    assert_equal 1, request.dig(:button, :request_users, :max_quantity)
    assert_equal true, request.dig(:button, :request_users, :request_name)
    assert_equal true, request.dig(:button, :request_users, :request_username)
    assert_equal "prepared-1", prepared.fetch("prepared_id")

    captured = @picker.capture(
      "message" => {
        "from" => { "id" => 77 },
        "users_shared" => {
          "request_id" => request_id,
          "users" => [{
            "user_id" => 88,
            "first_name" => "Ada",
            "last_name" => "Lovelace",
            "username" => "ada"
          }]
        }
      }
    )

    assert_equal true, captured
    assert_equal(
      {
        "status" => "selected",
        "recipient" => {
          "user_id" => "88",
          "name" => "Ada Lovelace",
          "username" => "ada"
        }
      },
      @picker.result(token: prepared.fetch("token"), requester_id: 77)
    )
  end

  def test_does_not_expose_selection_to_another_requester
    prepared = @picker.prepare(requester_id: 77)

    assert_equal(
      { "status" => "expired" },
      @picker.result(token: prepared.fetch("token"), requester_id: 99)
    )
  end

  def test_expires_pending_request
    prepared = @picker.prepare(requester_id: 77)
    @now += 61

    assert_equal(
      { "status" => "expired" },
      @picker.result(token: prepared.fetch("token"), requester_id: 77)
    )
  end
end
