# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "net/http"
require "zero_x_da/market/telegram_bot/market_api"

class MarketAPIPurchaseTest < Minitest::Test
  class StubbedMarketAPI < ZeroXDA::Market::TelegramBot::MarketAPI
    attr_reader :uris, :requests

    def initialize(outcomes:)
      @outcomes = outcomes
      @uris = []
      @requests = []
      super(base_url: "https://market.example", token: "token", sleeper: ->(_seconds) {})
    end

    private

    def perform_http_request(uri, request)
      @uris << uri
      @requests << request
      @outcomes.fetch(@requests.length - 1)
    end
  end

  def test_maps_purchase_to_existing_intent_quote_accept_and_execute_routes
    api = StubbedMarketAPI.new(
      outcomes: [
        response("201", resource("intent", "intent-1", capability: "manual.fulfillment")),
        response("201", resource("quote", "quote-1", intent_id: "intent-1")),
        response("201", resource("order", "order:quote-1", status: "accepted")),
        response("200", resource("order", "order:quote-1", status: "pending"))
      ]
    )

    intent = api.create_intent(
      capability: "manual.fulfillment",
      payload: { action: "purchase", product: { sku: "premium_3m" } },
      context: { customer_user_id: "user-1", channel: "telegram" }
    )
    quote = api.quote_intent(intent.fetch("id"))
    order = api.accept_quote(quote.fetch("id"))
    pending = api.execute_order(order.fetch("id"))

    assert_equal "pending", pending.dig("attributes", "status")
    assert_equal [
      "/v1/intents",
      "/v1/intents/intent-1/quotes",
      "/v1/quotes/quote-1/accept",
      "/v1/orders/order:quote-1/execute"
    ], api.uris.map(&:path)
    body = JSON.parse(api.requests.first.body)
    assert_equal "manual.fulfillment", body.fetch("capability")
    assert_equal "purchase", body.dig("payload", "action")
    assert_equal "user-1", body.dig("context", "customer_user_id")
  end

  def test_rejects_resource_ids_that_could_change_the_route
    api = StubbedMarketAPI.new(outcomes: [])

    error = assert_raises(ArgumentError) { api.order("../../operator/tasks") }

    assert_equal "resource id is invalid", error.message
    assert_empty api.requests
  end

  private

  def resource(type, id, **attributes)
    JSON.generate("data" => { "type" => type, "id" => id, "attributes" => attributes.transform_keys(&:to_s) })
  end

  def response(status, body)
    response_class = status == "201" ? Net::HTTPCreated : Net::HTTPOK
    value = response_class.new("1.1", status, "response")
    value.instance_variable_set(:@read, true)
    value.instance_variable_set(:@body, body)
    value
  end
end