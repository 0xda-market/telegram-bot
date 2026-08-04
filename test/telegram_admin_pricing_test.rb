# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"
require "rack/mock"
require "tmpdir"
require "zero_x_da/market/telegram_bot/telegram_mini_app"

class TelegramAdminPricingTest < Minitest::Test
  class Service
    attr_reader :requests

    def initialize
      @requests = []
    end

    def admin_price_proposal(init_data:, locale:)
      @requests << [:proposal, init_data, locale]
      {
        "data" => [
          {
            "type" => "price_proposal",
            "id" => "premium_3m",
            "attributes" => { "current_amount_usdt" => "12.5" }
          }
        ],
        "meta" => { "revision" => 7, "generated_at" => "2026-08-02T23:00:00Z" }
      }
    end

    def admin_price_history(init_data:, limit:)
      @requests << [:history, init_data, limit]
      {
        "data" => [
          {
            "type" => "price_history",
            "id" => "7",
            "attributes" => { "sku" => "premium_3m", "amount_usdt" => "12.5" }
          }
        ],
        "meta" => { "revision" => 7 }
      }
    end

    def apply_admin_prices(init_data:, revision:, prices:)
      @requests << [:apply, init_data, revision, prices]
      {
        "data" => prices.each_with_index.map do |price, index|
          {
            "type" => "price",
            "id" => price.fetch("sku"),
            "attributes" => price.merge("applied_at" => "2026-08-02T23:01:00Z")
          }
        end,
        "meta" => { "revision" => revision + prices.length }
      }
    end
  end

  def setup
    @directory = Dir.mktmpdir
    File.write(File.join(@directory, "index.html"), "<h1>Mini App</h1>")
    @service = Service.new
    @client = Rack::MockRequest.new(
      ZeroXDA::Market::TelegramBot::TelegramMiniApp.new(service: @service, root: @directory)
    )
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_routes_revisioned_pricing_documents_through_the_signed_session
    proposal = @client.get(
      "/webapp/admin/prices/proposal?locale=uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )
    history = @client.get(
      "/webapp/admin/prices/history?limit=12",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )
    applied = @client.post(
      "/webapp/admin/prices",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(
        revision: 7,
        prices: [
          { sku: "premium_3m", amount_usdt: "12.75" },
          { sku: "uah", amount_usdt: "0.024" }
        ]
      )
    )

    assert_equal 200, proposal.status, proposal.body
    assert_equal 7, JSON.parse(proposal.body).dig("meta", "revision")
    assert_equal 200, history.status, history.body
    assert_equal 201, applied.status, applied.body
    assert_equal "ok", JSON.parse(applied.body).fetch("status")
    assert_equal 9, JSON.parse(applied.body).dig("meta", "revision")
    assert_equal [:proposal, "signed-init-data", "uk_UA"], @service.requests[0]
    assert_equal [:history, "signed-init-data", "12"], @service.requests[1]
    assert_equal(
      [
        :apply,
        "signed-init-data",
        7,
        [
          { "sku" => "premium_3m", "amount_usdt" => "12.75" },
          { "sku" => "uah", "amount_usdt" => "0.024" }
        ]
      ],
      @service.requests[2]
    )
  end
end
