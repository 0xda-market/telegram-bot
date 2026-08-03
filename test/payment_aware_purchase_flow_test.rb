# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/purchase_flow"

class PaymentAwarePurchaseFlowTest < Minitest::Test
  class Market
    attr_reader :calls

    def initialize(order_status: "payment_pending")
      @order_status = order_status
      @calls = []
    end

    def create_marketplace_quote(**attributes)
      @calls << [:quote, attributes]
      { "type" => "quote", "id" => "quote-1", "attributes" => { "quantity" => attributes.fetch(:quantity) } }
    end

    def accept_marketplace_quote(**attributes)
      @calls << [:accept, attributes]
      {
        "type" => "order",
        "id" => "order-1",
        "attributes" => {
          "status" => @order_status,
          "inventory_status" => @order_status == "payment_pending" ? "payment_pending" : "committed",
          "payment_status" => @order_status == "payment_pending" ? "pending" : "confirmed"
        }
      }
    end

    def marketplace_order(**attributes)
      @calls << [:refresh, attributes]
      {
        "type" => "order",
        "id" => attributes.fetch(:order_id),
        "attributes" => { "status" => @order_status }
      }
    end

    def execute_marketplace_order(**attributes)
      @calls << [:execute, attributes]
      {
        "type" => "order",
        "id" => attributes.fetch(:order_id),
        "attributes" => { "status" => "pending" }
      }
    end
  end

  def test_accept_returns_payment_pending_order_without_execution
    market = Market.new
    flow = ZeroXDA::Market::TelegramBot::PurchaseFlow.new(market_api: market)

    order = flow.accept(quote_id: "quote-1", user: { "id" => "client-1" })

    assert_equal "payment_pending", order.dig("attributes", "status")
    assert_equal [[:accept, { actor_user_id: "client-1", quote_id: "quote-1" }]], market.calls
  end

  def test_refresh_does_not_execute_while_payment_is_pending
    market = Market.new
    flow = ZeroXDA::Market::TelegramBot::PurchaseFlow.new(market_api: market)

    order = flow.refresh(order_id: "order-1", user: { "id" => "client-1" })

    assert_equal "payment_pending", order.dig("attributes", "status")
    assert_equal [[:refresh, { actor_user_id: "client-1", order_id: "order-1" }]], market.calls
  end

  def test_accept_preserves_legacy_marketplace_execution_when_core_returns_accepted
    market = Market.new(order_status: "accepted")
    flow = ZeroXDA::Market::TelegramBot::PurchaseFlow.new(market_api: market)

    order = flow.accept(quote_id: "quote-1", user: { "id" => "client-1" })

    assert_equal "pending", order.dig("attributes", "status")
    assert_equal %i[accept execute], market.calls.map(&:first)
  end
end
