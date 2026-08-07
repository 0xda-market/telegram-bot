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
        query_id: "query-1",
        subject: "opaque-subject"
      )
    end
  end

  class Market
    attr_reader :authentications, :bootstrap_requests, :listing_requests, :admin_requests

    def initialize
      @authentications = []
      @bootstrap_requests = []
      @listing_requests = []
      @admin_requests = []
    end

    def authenticate_telegram(user:, chat:)
      @authentications << { user: user, chat: chat }
      {
        "type" => "user",
        "id" => "internal-user-id",
        "attributes" => { "role" => "broker", "status" => "active" }
      }
    end

    def currencies(locale:)
      [
        {
          "type" => "currency",
          "id" => "USDT",
          "attributes" => { "short_name" => "USDT", "name" => "Tether" }
        }
      ]
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

    def broker_listings(actor_user_id:)
      @listing_requests << [:list, actor_user_id]
      [listing]
    end

    def create_broker_listing(**attributes)
      @listing_requests << [:create, attributes]
      listing
    end

    def update_broker_listing(**attributes)
      @listing_requests << [:update, attributes]
      listing.merge("attributes" => listing.fetch("attributes").merge("version" => 1))
    end

    def withdraw_broker_listing(**attributes)
      @listing_requests << [:withdraw, attributes]
      listing.merge("attributes" => listing.fetch("attributes").merge("status" => "withdrawn", "version" => 2))
    end

    def create_admin_product(**attributes)
      @admin_requests << [:create_product, attributes]
      {
        "type" => "product",
        "id" => attributes.fetch(:sku),
        "attributes" => attributes.fetch(:attributes).merge("version" => 0)
      }
    end

    def listing
      {
        "type" => "broker_listing",
        "id" => "listing-1",
        "attributes" => {
          "sku" => "btc",
          "quantity" => "0.25",
          "available_quantity" => "0.25",
          "reserved_quantity" => "0",
          "sold_quantity" => "0",
          "price_amount" => "65000",
          "currency" => "USDT",
          "status" => "active",
          "version" => 0
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

    def quote(sku:, quantity:, recipient:, user:, telegram_user:, chat:, locale:)
      @quotes << {
        sku: sku,
        quantity: quantity,
        recipient: recipient,
        user: user,
        telegram_user: telegram_user,
        chat: chat,
        locale: locale
      }
      {
        "type" => "quote",
        "id" => "quote-1",
        "attributes" => {
          "quantity" => quantity,
          "total_price_usdt" => "13.25",
          "currency" => "USDT",
          "expires_at" => "2026-07-31T18:00:00Z"
        }
      }
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
    assert_equal "broker", document.dig("meta", "user", "role")
    assert_equal "active", document.dig("meta", "user", "status")
    assert_equal "broker", document.dig("meta", "session", "role")
    assert_equal "opaque-subject", document.dig("meta", "session", "subject")
    assert_equal "development", document.dig("meta", "session", "environment")
    assert_equal "USDT", document.dig("meta", "currencies", 0, "id")
    refute document.dig("meta", "user").key?("id")
    assert_equal [{ locale: "uk_UA", currency: "USDT" }], @market.bootstrap_requests
    assert_equal 1, @market.authentications.length
  end

  def test_quote_passes_single_quantity_recipient_and_verified_identity_without_an_extra_catalog_read
    document = @service.quote(
      init_data: "signed",
      sku: "premium_3m",
      quantity: "1",
      recipient: { "mode" => "username", "username" => "recipient" },
      locale: "uk_UA"
    )

    assert_equal "quote-1", document.dig("data", "id")
    assert_equal "1", document.dig("data", "attributes", "quantity")
    assert_equal "premium_3m", @purchase.quotes.first.fetch(:sku)
    assert_equal "1", @purchase.quotes.first.fetch(:quantity)
    assert_equal({ "mode" => "username", "username" => "recipient" }, @purchase.quotes.first.fetch(:recipient))
    assert_equal "internal-user-id", @purchase.quotes.first.dig(:user, "id")
    assert_empty @market.bootstrap_requests
  end

  def test_accept_and_refresh_use_the_verified_internal_user
    accepted = @service.accept(init_data: "signed", quote_id: "quote-1")
    refreshed = @service.refresh(init_data: "signed", order_id: "order-1")

    assert_equal "pending", accepted.dig("data", "attributes", "status")
    assert_equal "succeeded", refreshed.dig("data", "attributes", "status")
    assert_equal "internal-user-id", @purchase.accepts.first.dig(:user, "id")
    assert_equal "internal-user-id", @purchase.refreshes.first.dig(:user, "id")
  end

  def test_broker_listing_operations_use_the_verified_internal_user
    listed = @service.broker_listings(init_data: "signed")
    created = @service.create_broker_listing(
      init_data: "signed", sku: "btc", quantity: "0.25", price_amount: "65000", currency: "USDT"
    )
    updated = @service.update_broker_listing(
      init_data: "signed", listing_id: "listing-1", quantity: "0.5", price_amount: "64000",
      currency: "USDT", version: 0
    )
    withdrawn = @service.withdraw_broker_listing(
      init_data: "signed", listing_id: "listing-1", version: 1
    )

    assert_equal "listing-1", listed.dig("data", 0, "id")
    assert_equal "listing-1", created.dig("data", "id")
    assert_equal 1, updated.dig("data", "attributes", "version")
    assert_equal "withdrawn", withdrawn.dig("data", "attributes", "status")
    assert_equal [:list, "internal-user-id"], @market.listing_requests[0]
    assert_equal "internal-user-id", @market.listing_requests[1][1].fetch(:actor_user_id)
    assert_equal "internal-user-id", @market.listing_requests[2][1].fetch(:actor_user_id)
    assert_equal "internal-user-id", @market.listing_requests[3][1].fetch(:actor_user_id)
  end

  def test_product_creation_uses_the_verified_internal_administrator
    document = @service.create_admin_product(
      init_data: "signed",
      sku: "premium_12m",
      attributes: {
        "short_name" => "Premium · 12m",
        "status" => "inactive",
        "position" => 3,
        "marketable" => true,
        "metadata" => { "family" => "telegram_premium", "duration_months" => 12 }
      },
      localization: {
        "locale" => "uk_UA",
        "full_name" => "Telegram Premium на 12 місяців",
        "button_label" => "Premium · 12 міс."
      }
    )

    assert_equal "premium_12m", document.dig("data", "id")
    request = @market.admin_requests.first.fetch(1)
    assert_equal "internal-user-id", request.fetch(:actor_user_id)
    assert_equal "inactive", request.dig(:attributes, "status")
    assert_equal "uk_UA", request.dig(:localization, "locale")
  end
end
