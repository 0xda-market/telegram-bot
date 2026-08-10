# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/market_api"
require "zero_x_da/market/telegram_bot/payment_terms"
require "zero_x_da/market/telegram_bot/telegram_stars_payments"

class TelegramStarsPaymentsTest < Minitest::Test
  class Telegram
    attr_reader :invoices, :pre_checkout_answers, :refunds

    def initialize
      @invoices = []
      @pre_checkout_answers = []
      @refunds = []
    end

    def create_invoice_link(title:, description:, payload:, amount:)
      @invoices << { title: title, description: description, payload: payload, amount: amount }
      "https://t.me/$invoice-#{@invoices.length}"
    end

    def answer_pre_checkout_query(pre_checkout_query_id:, ok:, error_message: nil)
      @pre_checkout_answers << { id: pre_checkout_query_id, ok: ok, error_message: error_message }
      true
    end

    def refund_star_payment(user_id:, telegram_payment_charge_id:)
      @refunds << { user_id: user_id, charge_id: telegram_payment_charge_id }
      true
    end
  end

  class Market
    attr_reader :confirmations
    attr_accessor :confirmation_error

    def initialize
      @confirmations = []
    end

    def authenticate_telegram(user:, chat:)
      { "id" => "market-user-1", "attributes" => { "provider_user_id" => user.fetch("id").to_s, "chat" => chat.fetch("id") } }
    end

    def confirm_marketplace_payment(**arguments)
      raise confirmation_error if confirmation_error

      @confirmations << arguments
      { "type" => "order", "id" => arguments.fetch(:order_id), "attributes" => { "status" => "pending" } }
    end
  end

  def setup
    @now = Time.utc(2026, 8, 10, 21, 0, 0)
    @telegram = Telegram.new
    @market = Market.new
    @terms = ZeroXDA::Market::TelegramBot::PaymentTerms.new(
      public_url: "https://market.example",
      clock: -> { @now }
    )
    @payments = ZeroXDA::Market::TelegramBot::TelegramStarsPayments.new(
      telegram_api: @telegram,
      market_api: @market,
      signing_secret: "s" * 32,
      payment_terms: @terms,
      clock: -> { @now }
    )
    @user = { "id" => 77, "username" => "buyer" }
  end

  def test_invoice_requires_explicit_current_terms_consent
    error = assert_raises(ZeroXDA::Market::TelegramBot::TelegramStarsPayments::InvalidPayload) do
      @payments.attach_invoice(
        order: payment_pending_order,
        telegram_user: @user,
        consent: nil
      )
    end

    assert_match(/terms must be accepted/i, error.message)
    assert_empty @telegram.invoices
  end

  def test_invoice_payload_is_signed_bounded_and_binds_order_user_amount_expiry_and_terms
    order = attach_order
    invoice = @telegram.invoices.fetch(0)

    assert_equal "https://t.me/$invoice-1", order.dig("attributes", "payment", "invoice_link")
    assert_equal 962, invoice.fetch(:amount)
    assert_operator invoice.fetch(:payload).bytesize, :<=, 128
    assert_equal ZeroXDA::Market::TelegramBot::PaymentTerms::VERSION,
                 order.dig("attributes", "payment", "terms", "version")

    @payments.handle(
      "pre_checkout_query" => {
        "id" => "pre-1",
        "from" => @user,
        "currency" => "XTR",
        "total_amount" => 962,
        "invoice_payload" => invoice.fetch(:payload)
      }
    )
    assert_equal({ id: "pre-1", ok: true, error_message: nil }, @telegram.pre_checkout_answers.last)

    @payments.handle(
      "pre_checkout_query" => {
        "id" => "pre-2",
        "from" => @user,
        "currency" => "XTR",
        "total_amount" => 961,
        "invoice_payload" => invoice.fetch(:payload)
      }
    )
    refute @telegram.pre_checkout_answers.last.fetch(:ok)
  end

  def test_realistic_uuid_order_id_stays_within_telegram_payload_limit
    order = payment_pending_order
    order["id"] = "order:550e8400-e29b-41d4-a716-446655440000"

    @payments.attach_invoice(
      order: order,
      telegram_user: @user,
      consent: consent
    )

    assert_operator @telegram.invoices.last.fetch(:payload).bytesize, :<=, 128
  end

  def test_successful_payment_is_the_only_path_to_core_confirmation_and_preserves_terms_evidence
    invoice = invoice_payload

    @payments.handle(successful_update(invoice.fetch(:payload), charge_id: "charge-1"))

    confirmation = @market.confirmations.fetch(0)
    assert_equal "market-user-1", confirmation.fetch(:actor_user_id)
    assert_equal "order:quote-1", confirmation.fetch(:order_id)
    assert_equal "charge-1", confirmation.fetch(:reference)
    assert_equal "telegram_stars", confirmation.fetch(:provider)
    assert_equal 962, confirmation.fetch(:amount)
    assert_equal "XTR", confirmation.fetch(:currency)
    assert_equal ZeroXDA::Market::TelegramBot::PaymentTerms::VERSION,
                 confirmation.dig(:data, :terms_version)
    assert_equal @terms.digest(locale: "en_US"), confirmation.dig(:data, :terms_sha256)
    assert_equal "en_US", confirmation.dig(:data, :terms_locale)
    refute_empty confirmation.dig(:data, :terms_accepted_at).to_s
    assert_empty @telegram.refunds
  end

  def test_tampered_successful_payment_is_refunded_instead_of_fulfilled
    invoice = invoice_payload
    tampered = invoice.fetch(:payload).sub(".962.", ".961.")

    @payments.handle(successful_update(tampered, charge_id: "charge-tampered", amount: 961))

    assert_empty @market.confirmations
    assert_equal [{ user_id: 77, charge_id: "charge-tampered" }], @telegram.refunds
  end

  def test_terminal_core_rejection_refunds_but_transient_failure_is_retried
    invoice = invoice_payload
    @market.confirmation_error = ZeroXDA::Market::TelegramBot::MarketAPI::Error.new(
      "expired",
      code: "payment_expired",
      status: 409
    )
    @payments.handle(successful_update(invoice.fetch(:payload), charge_id: "charge-expired"))
    assert_equal "charge-expired", @telegram.refunds.last.fetch(:charge_id)

    @market.confirmation_error = ZeroXDA::Market::TelegramBot::MarketAPI::Error.new(
      "temporarily unavailable",
      code: "market_api_error",
      status: 503
    )
    assert_raises(ZeroXDA::Market::TelegramBot::MarketAPI::Error) do
      @payments.handle(successful_update(invoice.fetch(:payload), charge_id: "charge-retry"))
    end
    refute @telegram.refunds.any? { |entry| entry.fetch(:charge_id) == "charge-retry" }
  end

  def test_expired_pre_checkout_is_rejected_without_calling_core
    invoice = invoice_payload
    @now += 61

    @payments.handle(
      "pre_checkout_query" => {
        "id" => "pre-expired",
        "from" => @user,
        "currency" => "XTR",
        "total_amount" => 962,
        "invoice_payload" => invoice.fetch(:payload)
      }
    )

    refute @telegram.pre_checkout_answers.last.fetch(:ok)
    assert_empty @market.confirmations
  end

  private

  def consent
    @terms.server_accept(telegram_user_id: @user.fetch("id"), locale: "en_US")
  end

  def attach_order
    @payments.attach_invoice(
      order: payment_pending_order,
      telegram_user: @user,
      consent: consent
    )
  end

  def invoice_payload
    attach_order
    @telegram.invoices.last
  end

  def payment_pending_order
    {
      "type" => "order",
      "id" => "order:quote-1",
      "attributes" => {
        "status" => "payment_pending",
        "payload" => { "product" => { "name" => "Telegram Premium 3 months" } },
        "payment" => {
          "status" => "pending",
          "expires_at" => (@now + 60).iso8601(6),
          "provider" => {
            "provider" => "telegram_stars",
            "currency" => "XTR",
            "amount" => "962"
          }
        }
      }
    }
  end

  def successful_update(payload, charge_id:, amount: 962)
    {
      "message" => {
        "from" => @user,
        "chat" => { "id" => 770 },
        "successful_payment" => {
          "currency" => "XTR",
          "total_amount" => amount,
          "invoice_payload" => payload,
          "telegram_payment_charge_id" => charge_id,
          "provider_payment_charge_id" => ""
        }
      }
    }
  end
end
