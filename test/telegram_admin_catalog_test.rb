# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"
require "rack/mock"
require "tmpdir"
require "zero_x_da/market/telegram_bot/telegram_mini_app"

class TelegramAdminCatalogTest < Minitest::Test
  class Service
    attr_reader :requests

    def initialize
      @requests = []
    end

    def admin_products(init_data:, locale:)
      @requests << [:list, init_data, locale]
      { "data" => [product] }
    end

    def update_admin_product(init_data:, sku:, version:, attributes:)
      @requests << [:update, init_data, sku, version, attributes]
      { "data" => product(version: version + 1) }
    end

    def save_admin_product_localization(
      init_data:,
      sku:,
      locale:,
      full_name:,
      button_label:,
      version: nil
    )
      @requests << [:localization, init_data, sku, locale, full_name, button_label, version]
      {
        "data" => {
          "type" => "product_localization",
          "id" => "#{sku}:#{locale}",
          "attributes" => {
            "locale" => locale,
            "full_name" => full_name,
            "button_label" => button_label,
            "version" => version ? version + 1 : 0
          }
        }
      }
    end

    private

    def product(version: 2)
      {
        "type" => "product",
        "id" => "premium_3m",
        "attributes" => { "short_name" => "Premium · 3m", "version" => version }
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

  def test_routes_admin_product_and_localization_operations_through_signed_session
    listed = @client.get(
      "/webapp/admin/products?locale=uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )
    updated = @client.patch(
      "/webapp/admin/products/premium_3m",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(version: 2, attributes: { short_name: "Premium quarter" })
    )
    localized = @client.put(
      "/webapp/admin/products/premium_3m/localizations/uk_UA",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(
        full_name: "Telegram Premium на 3 місяці",
        button_label: "Premium · 3 міс.",
        version: 1
      )
    )

    assert_equal 200, listed.status
    assert_equal 200, updated.status
    assert_equal 200, localized.status
    assert_equal [:list, "signed-init-data", "uk_UA"], @service.requests[0]
    assert_equal(
      [:update, "signed-init-data", "premium_3m", 2, { "short_name" => "Premium quarter" }],
      @service.requests[1]
    )
    assert_equal(
      [
        :localization,
        "signed-init-data",
        "premium_3m",
        "uk_UA",
        "Telegram Premium на 3 місяці",
        "Premium · 3 міс.",
        1
      ],
      @service.requests[2]
    )
  end

  def test_creating_a_localization_returns_created
    response = @client.put(
      "/webapp/admin/products/premium_3m/localizations/fr_FR",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(full_name: "Telegram Premium 3 mois", button_label: "Premium · 3 mois")
    )

    assert_equal 201, response.status
    assert_nil @service.requests[0].last
  end
end
