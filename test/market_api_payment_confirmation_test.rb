# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/market_api"
require "zero_x_da/market/telegram_bot/market_api_payment_confirmation"
require "zero_x_da/market/telegram_bot/market_api_webapp"

class MarketAPIPaymentConfirmationTest < Minitest::Test
  class Harness < ZeroXDA::Market::TelegramBot::MarketAPI
    attr_reader :payment_calls

    def initialize
      @payment_calls = []
    end

    private

    def payment_confirmation_post(path, payload)
      @payment_calls << { path: path, payload: payload }
      {
        "data" => {
          "type" => "order",
          "id" => "order-1",
          "attributes" => { "payment_status" => "confirmed" }
        }
      }
    end

    def post(*)
      raise "generic retrying POST must not be used for payment confirmation"
    end
  end

  def test_confirmation_uses_the_bounded_single_attempt_path
    api = Harness.new

    order = api.confirm_marketplace_payment(
      actor_user_id: "user-1",
      order_id: "order-1",
      reference: "charge-1",
      provider: "telegram_stars",
      amount: 962,
      currency: "XTR",
      data: { telegram_payment_charge_id: "charge-1" }
    )

    assert_equal "order-1", order.fetch("id")
    call = api.payment_calls.fetch(0)
    assert_equal "v1/market/orders/order-1/payment/confirm", call.fetch(:path)
    assert_equal "charge-1", call.dig(:payload, :reference)
    assert_equal 962, call.dig(:payload, :amount)
  end
end
