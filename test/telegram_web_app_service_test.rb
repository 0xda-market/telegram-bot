# frozen_string_literal: true

require_relative "test_helper"
require "time"
require "zero_x_da/market/telegram_bot/telegram_web_app_service"

class TelegramWebAppServiceTest < Minitest::Test
  Session = ZeroXDA::Market::TelegramBot::TelegramWebAppAuth::Session

  class Authentication
    attr_reader :requests

    def initialize
      @requests = []
    end

    def verify(init_data)
      @requests << init_data
      Session.new(
        user: { "id" => 99, "username" => "sasha", "language_code" => "uk" },
        chat: { "id" => 990, "type" => "private" },
        auth_date: Time.utc(2026, 7, 31, 17, 0, 0),
        query_id: "query-1"
      )
    end
  end

  class Market
    attr_reader :authentications, :bootstrap_requests

    def initialize
      @authentications = []
      @bootstrap_requests = []
    end

    def authenticate_telegram(user:, chat:)
      @authentications << { user: user, chat: chat }
      {
        "type" => "user",
        "id" => "internal-user-id",
        "attributes" => { "role" => "client", "status" => "active" }
      }
    end

    def webapp_bootstrap(locale:, currency:)
      @bootstrap_requests << { locale: locale, currency: currency }
      {
        "data" => [
          {
            "type" => "product",
            "id" => "premium_3m",
            "attributes" => {
              "name" => "Telegram Premium 3 months",
              "price" => { "amount_usdt" => "13.25", "amount" => "13.25", "currency" => "USDT" }
            }
          }
        ],
        "meta" => {
          "schema_version" => 1,
          "snapshot_id" => "snapshot-1",
          "generated_at" => "2026-07-31T17:00:00Z",
          "count" => 1,
          "complete" => true,
          "pagination" => "client",
          "currency" => currency,
          "locale" => locale
        }
      }
    end
  end

  class Purchase
    attr_reader :quotes, :accepts, :refreshes

    def initialize
      @quotes = []
      @accepts = []
      @refreshes = []
    end

    def quote(product:, user:, telegram_user:, chat:, locale:)
      @quotes << {
        product: product,
        user: user,
        telegram_user: telegram_user,
        chat: chat,
        locale: locale
      }
      [
        { "id" => "intent-1" },
        { "type" => "quote", "id" => "quote-1", "attributes" => { "expires_at" => "2026-07-31T18:00:00Z" } }
      ]
    end

    def accept(quote_id:, user:)
      @accepts << { quote_id: quote_id, user: user }
      { "type" => "order", "id" => "order-1", "attributes" => { "status" => "pending" } }
    end

    def refresh(order_id:, user:)
      @refreshes << { order_id: order_id, user: user }
      { "type" => "order", "id" => order_id, "attributes" => { "status" => "succeeded" } }
    end
  end

  def setup
    @authentication = Authentication.new
    @market = Market.new
    @purchase = Purchase.new
    @service = ZeroXDA::Market::TelegramBot::TelegramWebAppService.new(
      market_api: @market,
      authentication: @authentication,
      purchase_flow: @purchase
    )
  end

  def test_bootstrap_returns_the_complete_core_snapshot_with_public_session_meta
    document = @service.bootstrap(init_data: "signed", locale: "uk")

    assert_equal "snapshot-1", document.dig("meta", "snapshot_id")
    assert_equal true, document.dig("meta", "complete")
    assert_equal "client", document.dig("meta", "pagination")
    assert_equal "telegram", document.dig("meta", "channel")
    assert_equal "client", document.dig("meta", "user", "role")
    assert_equal "active", document.dig("meta", "user", "status")
    refute document.dig("meta", "user").key?("id")
    assert_equal [{ locale: "uk_UA", currency: "USDT" }], @market.bootstrap_requests
    assert_equal 1, @market.authentications.length
  end

  def test_quote_revalidates_the_selected_product_against_a_fresh_complete_snapshot
    document = @service.quote(init_data: "signed", sku: "premium_3m", locale: "uk_UA")

    assert_equal "quote-1", document.dig("data", "id")
    assert_equal "snapshot-1", document.dig("meta", "snapshot_id")
    assert_equal "premium_3m", @purchase.quotes.first.dig(:product, "id")
    assert_equal "internal-user-id", @purchase.quotes.first.dig(:user, "id")
    assert_equal 1, @market.bootstrap_requests.length
  end

  def test_unknown_product_fails_before_creating_an_intent
    assert_raises(ArgumentError) do
      @service.quote(init_data: "signed", sku: "missing", locale: "uk_UA")
    end

    assert_empty @purchase.quotes
  end

  def test_accept_and_refresh_keep_purchase_ownership_checks_in_the_purchase_flow
    accepted = @service.accept(init_data: "signed", quote_id: "quote-1")
    refreshed = @service.refresh(init_data: "signed", order_id: "order-1")

    assert_equal "pending", accepted.dig("data", "attributes", "status")
    assert_equal "succeeded", refreshed.dig("data", "attributes", "status")
    assert_equal "internal-user-id", @purchase.accepts.first.dig(:user, "id")
    assert_equal "internal-user-id", @purchase.refreshes.first.dig(:user, "id")
  end
end
