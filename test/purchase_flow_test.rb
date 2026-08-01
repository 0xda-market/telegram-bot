# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/purchase_flow"

class PurchaseFlowTest < Minitest::Test
  PurchaseFlow = ZeroXDA::Market::TelegramBot::PurchaseFlow

  def test_quote_snapshot_carries_customer_and_channel_context
    market = FakeMarketAPI.new
    flow = PurchaseFlow.new(market_api: market)
    product = market.products(locale: "uk_UA", currency: "USDT").first

    intent, quote = flow.quote(
      product: product,
      user: { "id" => "owner-1" },
      telegram_user: { "id" => 77 },
      chat: { "id" => 770 },
      locale: "uk_UA"
    )

    assert_equal "purchase", intent.dig("attributes", "payload", "action")
    assert_equal "owner-1", intent.dig("attributes", "context", "customer_user_id")
    assert_equal "telegram", intent.dig("attributes", "context", "channel")
    assert_equal "77", intent.dig("attributes", "context", "telegram", "user_id")
    assert_equal "7.45", intent.dig("attributes", "payload", "product", "amount_usdt")
    assert_equal intent.fetch("id"), quote.dig("attributes", "intent_id")
  end

  def test_another_authenticated_user_cannot_accept_or_refresh_the_purchase
    market = FakeMarketAPI.new
    flow = PurchaseFlow.new(market_api: market)
    product = market.products(currency: "USDT").first
    _intent, quote = flow.quote(
      product: product,
      user: { "id" => "owner-1" },
      telegram_user: { "id" => 77 },
      chat: { "id" => 770 },
      locale: "en_US"
    )

    assert_raises(PurchaseFlow::AccessDenied) do
      flow.accept(quote_id: quote.fetch("id"), user: { "id" => "other-user" })
    end

    order = market.accept_quote(quote.fetch("id"))
    assert_raises(PurchaseFlow::AccessDenied) do
      flow.refresh(order_id: order.fetch("id"), user: { "id" => "other-user" })
    end
  end
end
