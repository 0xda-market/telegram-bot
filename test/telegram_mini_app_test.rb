# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"
require "rack/mock"
require "tmpdir"
require "zero_x_da/market/telegram_bot/telegram_mini_app"

class TelegramMiniAppTest < Minitest::Test
  class Service
    attr_reader :requests
    attr_accessor :failure

    def initialize
      @requests = []
    end

    def bootstrap(init_data:, locale:)
      raise failure if failure

      @requests << [:bootstrap, init_data, locale]
      {
        "data" => [],
        "meta" => {
          "schema_version" => 1,
          "snapshot_id" => "snapshot-1",
          "generated_at" => "2026-07-31T17:00:00Z",
          "count" => 0,
          "complete" => true,
          "pagination" => "client",
          "currency" => "USDT",
          "locale" => locale
        }
      }
    end

    def quote(init_data:, sku:, quantity:, locale:)
      @requests << [:quote, init_data, sku, quantity, locale]
      {
        "data" => {
          "type" => "quote",
          "id" => "quote-1",
          "attributes" => { "quantity" => quantity }
        }
      }
    end

    def accept(init_data:, quote_id:)
      @requests << [:accept, init_data, quote_id]
      { "data" => { "type" => "order", "id" => "order-1", "attributes" => { "status" => "pending" } } }
    end

    def refresh(init_data:, order_id:)
      @requests << [:refresh, init_data, order_id]
      { "data" => { "type" => "order", "id" => order_id, "attributes" => { "status" => "succeeded" } } }
    end

    def broker_listings(init_data:)
      @requests << [:broker_listings, init_data]
      { "data" => [] }
    end

    def create_broker_listing(init_data:, sku:, quantity:, price_amount:, currency:)
      @requests << [:create_broker_listing, init_data, sku, quantity, price_amount, currency]
      listing
    end

    def update_broker_listing(init_data:, listing_id:, quantity:, price_amount:, currency:, version:)
      @requests << [:update_broker_listing, init_data, listing_id, quantity, price_amount, currency, version]
      listing
    end

    def withdraw_broker_listing(init_data:, listing_id:, version:)
      @requests << [:withdraw_broker_listing, init_data, listing_id, version]
      listing
    end

    def create_admin_product(init_data:, sku:, attributes:, localization:)
      @requests << [:create_admin_product, init_data, sku, attributes, localization]
      {
        "data" => {
          "type" => "product",
          "id" => sku,
          "attributes" => attributes.merge("version" => 0)
        }
      }
    end

    def listing
      { "data" => { "type" => "broker_listing", "id" => "listing-1", "attributes" => { "status" => "active" } } }
    end
  end

  def setup
    @directory = Dir.mktmpdir
    File.write(File.join(@directory, "index.html"), "<h1>Mini App</h1>")
    File.write(File.join(@directory, "app.js"), "export const ready = true;\n")
    @service = Service.new
    @client = Rack::MockRequest.new(
      ZeroXDA::Market::TelegramBot::TelegramMiniApp.new(service: @service, root: @directory)
    )
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_redirects_to_the_trailing_slash_and_serves_static_assets
    redirect = @client.get("/webapp")
    index = @client.get("/webapp/")
    asset = @client.get("/webapp/app.js")

    assert_equal 302, redirect.status
    assert_equal "/webapp/", redirect["location"]
    assert_equal 200, index.status
    assert_equal "<h1>Mini App</h1>", index.body
    assert_equal "no-store", index["cache-control"]
    assert_equal 200, asset.status
    assert_includes asset["cache-control"], "max-age=300"
    assert_includes asset["content-security-policy"], "script-src 'self' https://telegram.org"
    assert_includes asset["content-security-policy"], "style-src 'self'"
    refute_includes asset["content-security-policy"], "unsafe-inline"
  end

  def test_serves_the_complete_catalog_bootstrap
    response = @client.get(
      "/webapp/bootstrap?locale=uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )

    assert_equal 200, response.status
    document = JSON.parse(response.body)
    assert_equal true, document.dig("meta", "complete")
    assert_equal "client", document.dig("meta", "pagination")
    assert_equal [[:bootstrap, "signed-init-data", "uk_UA"]], @service.requests
  end

  def test_routes_quantity_quote_acceptance_and_order_refresh
    quote = @client.post(
      "/webapp/quotes",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(sku: "premium_3m", quantity: "2", locale: "uk_UA")
    )
    accepted = @client.post(
      "/webapp/quotes/quote-1/accept",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: "{}"
    )
    refreshed = @client.get(
      "/webapp/orders/order-1",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )

    assert_equal 201, quote.status
    assert_equal "ok", JSON.parse(quote.body).fetch("status")
    assert_equal "2", JSON.parse(quote.body).dig("data", "attributes", "quantity")
    assert_equal 201, accepted.status
    assert_equal "ok", JSON.parse(accepted.body).fetch("status")
    assert_equal 200, refreshed.status
    assert_equal(
      [
        [:quote, "signed-init-data", "premium_3m", "2", "uk_UA"],
        [:accept, "signed-init-data", "quote-1"],
        [:refresh, "signed-init-data", "order-1"]
      ],
      @service.requests
    )
  end

  def test_routes_administrator_product_creation
    response = @client.post(
      "/webapp/admin/products",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(
        sku: "premium_12m",
        attributes: {
          short_name: "Premium · 12m",
          status: "inactive",
          position: 3,
          marketable: true,
          metadata: { family: "telegram_premium", duration_months: 12 }
        },
        localization: {
          locale: "uk_UA",
          full_name: "Telegram Premium на 12 місяців",
          button_label: "Premium · 12 міс."
        }
      )
    )

    assert_equal 201, response.status, response.body
    assert_equal "ok", JSON.parse(response.body).fetch("status")
    request = @service.requests.fetch(0)
    assert_equal :create_admin_product, request.fetch(0)
    assert_equal "signed-init-data", request.fetch(1)
    assert_equal "premium_12m", request.fetch(2)
    assert_equal "inactive", request.fetch(3).fetch("status")
    assert_equal "uk_UA", request.fetch(4).fetch("locale")
  end

  def test_maps_invalid_telegram_sessions_to_unauthorized
    @service.failure = ZeroXDA::Market::TelegramBot::TelegramWebAppAuth::Invalid.new("expired")

    response = @client.get(
      "/webapp/bootstrap?locale=uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "expired"
    )

    assert_equal 401, response.status
    assert_equal "invalid_telegram_session", JSON.parse(response.body).fetch("error")
  end

  def test_routes_broker_listing_lifecycle
    listed = @client.get(
      "/webapp/broker/listings",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )
    created = @client.post(
      "/webapp/broker/listings",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(sku: "btc", quantity: "0.25", price_amount: "65000", currency: "USDT")
    )
    updated = @client.patch(
      "/webapp/broker/listings/listing-1",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(quantity: "0.5", price_amount: "64000", currency: "USDT", version: 0)
    )
    withdrawn = @client.delete(
      "/webapp/broker/listings/listing-1",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(version: 1)
    )

    assert_equal 200, listed.status
    assert_equal 201, created.status
    assert_equal "ok", JSON.parse(created.body).fetch("status")
    assert_equal 200, updated.status
    assert_equal 200, withdrawn.status
    assert_equal [:broker_listings, "signed-init-data"], @service.requests[0]
    assert_equal [:create_broker_listing, "signed-init-data", "btc", "0.25", "65000", "USDT"], @service.requests[1]
    assert_equal(
      [:update_broker_listing, "signed-init-data", "listing-1", "0.5", "64000", "USDT", 0],
      @service.requests[2]
    )
    assert_equal [:withdraw_broker_listing, "signed-init-data", "listing-1", 1], @service.requests[3]
  end
end
