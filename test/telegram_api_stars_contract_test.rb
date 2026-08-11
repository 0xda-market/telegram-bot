# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/telegram_api"

class TelegramAPIStarsContractTest < Minitest::Test
  class Harness < ZeroXDA::Market::TelegramBot::TelegramAPI
    attr_reader :calls
    attr_accessor :post_error

    def initialize
      @calls = []
    end

    private

    def post(method, payload, **options)
      @calls << { method: method, payload: payload, options: options }
      raise post_error if post_error

      true
    end
  end

  def setup
    @api = Harness.new
  end

  def test_stars_invoice_uses_xtr_one_price_and_no_provider_token
    @api.create_invoice_link(
      title: "Premium 3m",
      description: "Digital product",
      payload: "signed-payload",
      amount: 962
    )

    call = @api.calls.last
    assert_equal "createInvoiceLink", call.fetch(:method)
    payload = call.fetch(:payload)
    assert_equal "XTR", payload.fetch(:currency)
    assert_equal [{ label: "Premium 3m", amount: 962 }], payload.fetch(:prices)
    refute payload.key?(:provider_token)
  end

  def test_pre_checkout_answer_reserves_protocol_time_margin
    @api.answer_pre_checkout_query(pre_checkout_query_id: "pre-1", ok: true)

    call = @api.calls.last
    assert_equal "answerPreCheckoutQuery", call.fetch(:method)
    assert_equal({ open_timeout: 2, read_timeout: 5 }, call.fetch(:options))
  end

  def test_duplicate_refund_is_idempotent_but_other_errors_surface
    @api.post_error = ZeroXDA::Market::TelegramBot::TelegramAPI::Error.new(
      "Bad Request: CHARGE_ALREADY_REFUNDED"
    )
    assert_equal true, @api.refund_star_payment(
      user_id: 77,
      telegram_payment_charge_id: "charge-1"
    )

    @api.post_error = ZeroXDA::Market::TelegramBot::TelegramAPI::Error.new("Bad Request: charge invalid")
    assert_raises(ZeroXDA::Market::TelegramBot::TelegramAPI::Error) do
      @api.refund_star_payment(user_id: 77, telegram_payment_charge_id: "charge-2")
    end
  end

  def test_webhook_configuration_includes_pre_checkout_queries
    @api.set_webhook(url: "https://market.example/telegram/webhook", secret_token: "secret")

    updates = @api.calls.last.fetch(:payload).fetch(:allowed_updates)
    assert_includes updates, "pre_checkout_query"
    assert_includes updates, "message"
  end
end
