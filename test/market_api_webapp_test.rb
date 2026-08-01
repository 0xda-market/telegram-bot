# frozen_string_literal: true

require_relative "test_helper"
require "net/http"
require "zero_x_da/telegram_bot/market_api_webapp"

class MarketAPIWebAppTest < Minitest::Test
  class StubbedAPI < ZeroXDA::TelegramBot::MarketAPI
    attr_reader :request, :uri

    private

    def perform_http_request(uri, request)
      @uri = uri
      @request = request
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(
        :@body,
        '{"data":[],"meta":{"complete":true,"pagination":"client","snapshot_id":"snapshot-1"}}'
      )
      response
    end
  end

  def test_loads_the_complete_public_bootstrap_without_exposing_the_market_token
    api = StubbedAPI.new(base_url: "https://market.example", token: "secret-market-token")

    document = api.webapp_bootstrap(locale: "uk_UA", currency: "USDT")

    assert_equal true, document.dig("meta", "complete")
    assert_equal "client", document.dig("meta", "pagination")
    assert_equal "/v1/webapp/bootstrap", api.uri.path
    assert_equal({ "locale" => "uk_UA", "currency" => "USDT" }, URI.decode_www_form(api.uri.query).to_h)
    assert_nil api.request["authorization"]
  end
end
