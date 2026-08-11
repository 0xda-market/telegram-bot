# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "rack/mock"
require "zero_x_da/market/telegram_bot/http_app"

class PaymentWebhookPriorityTest < Minitest::Test
  class Bot
    attr_reader :updates

    def initialize
      @updates = []
    end

    def handle(update)
      @updates << update
    end
  end

  class Observer
    attr_reader :updates

    def initialize
      @updates = []
    end

    def capture(update)
      @updates << update
    end
  end

  class PaymentHandler
    attr_reader :updates
    attr_accessor :error

    def initialize
      @updates = []
    end

    def handles?(update)
      update.key?("pre_checkout_query") || update.dig("message", "successful_payment")
    end

    def handle(update)
      @updates << update
      raise error if error
    end
  end

  def setup
    @bot = Bot.new
    @observer = Observer.new
    @payments = PaymentHandler.new
    @app = ZeroXDA::Market::TelegramBot::TelegramBotHTTPApp.new(
      bot: @bot,
      webhook_secret: "webhook-secret",
      telegram_username: "market_test_bot",
      dispatcher: ->(&task) { task.call },
      update_observer: @observer,
      payment_handler: @payments
    )
  end

  def test_payment_update_bypasses_non_payment_observer_and_bot_dispatch
    response = post_webhook(
      "update_id" => 1,
      "pre_checkout_query" => { "id" => "pre-1" }
    )

    assert_equal 200, response.status
    assert_equal 1, @payments.updates.length
    assert_empty @observer.updates
    assert_empty @bot.updates
  end

  def test_payment_failure_returns_retryable_http_error
    @payments.error = RuntimeError.new("temporary failure")

    response = post_webhook(
      "update_id" => 2,
      "message" => { "successful_payment" => { "currency" => "XTR" } }
    )

    assert_equal 503, response.status
    assert_equal "payment_processing_unavailable", JSON.parse(response.body).fetch("error")
    assert_empty @observer.updates
    assert_empty @bot.updates
  end

  private

  def post_webhook(document)
    Rack::MockRequest.new(@app).post(
      "/telegram/webhook",
      "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN" => "webhook-secret",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(document)
    )
  end
end
