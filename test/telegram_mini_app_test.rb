# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "rack/mock"
require "tmpdir"
require "zero_x_da/market_client_bot/telegram_mini_app"

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

    def quote(init_data:, sku:, locale:)
      @requests << [:quote, init_data, sku, locale]
      { "data" => { "type" => "quote", "id" => "quote-1", "attributes" => {} } }
    end

    def accept(init_data:, quote_id:)
      @requests << [:accept, init_data, quote_id]
      { "data" => { "type" => "order", "id" => "order-1", "attributes" => { "status" => "pending" } } }
    end

    def refresh(init_data:, order_id:)
      @requests << [:refresh, init_data, order_id]
      { "data" => { "type" => "order", "id" => order_id, "attributes" => { "status" => "succeeded" } } }
    end
  end

  def setup
    @directory = Dir.mktmpdir
    File.write(File.join(@directory, "index.html"), "<h1>Mini App</h1>")
    File.write(File.join(@directory, "app.js"), "export const ready = true;\n")
    @service = Service.new
    @client = Rack::MockRequest.new(
      ZeroXDA::MarketClientBot::TelegramMiniApp.new(service: @service, root: @directory)
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
    assert_includes asset["content-security-policy"], "https://telegram.org"
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

  def test_routes_quote_acceptance_and_order_refresh
    quote = @client.post(
      "/webapp/quotes",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(sku: "premium_3m", locale: "uk_UA")
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
    assert_equal 201, accepted.status
    assert_equal 200, refreshed.status
    assert_equal(
      [
        [:quote, "signed-init-data", "premium_3m", "uk_UA"],
        [:accept, "signed-init-data", "quote-1"],
        [:refresh, "signed-init-data", "order-1"]
      ],
      @service.requests
    )
  end

  def test_maps_invalid_telegram_sessions_to_unauthorized
    @service.failure = ZeroXDA::MarketClientBot::TelegramWebAppAuth::Invalid.new("expired")

    response = @client.get(
      "/webapp/bootstrap?locale=uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "expired"
    )

    assert_equal 401, response.status
    assert_equal "invalid_telegram_session", JSON.parse(response.body).fetch("error")
  end
end
