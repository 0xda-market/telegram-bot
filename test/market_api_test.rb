# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market_client_bot/market_api"

class MarketAPITest < Minitest::Test
  class StubbedMarketAPI < ZeroXDA::MarketClientBot::MarketAPI
    attr_reader :attempts, :backoffs, :uris, :requests

    def initialize(outcomes:, **options)
      @outcomes = outcomes
      @attempts = 0
      @backoffs = []
      @uris = []
      @requests = []
      super(**options, sleeper: ->(seconds) { @backoffs << seconds })
    end

    private

    def perform_http_request(uri, request)
      @attempts += 1
      @uris << uri
      @requests << request
      outcome = @outcomes.fetch(@attempts - 1)
      raise outcome if outcome.is_a?(Exception)

      outcome
    end
  end

  def test_retries_a_cold_start_timeout
    api = api_with(Timeout::Error.new("cold start"), json_response)

    assert_equal({ "status" => "ok" }, api.health)
    assert_equal 2, api.attempts
    assert_equal [2], api.backoffs
  end

  def test_loads_products_from_the_authenticated_catalog_endpoint
    payload = '{"data":[{"id":"ton","attributes":{"name":"TON"}}]}'
    api = api_with(response("200", payload))

    assert_equal "ton", api.products(locale: "uk_UA").first.fetch("id")
    assert_equal 1, api.attempts
    assert_equal "locale=uk_UA", api.uris.first.query
  end

  def test_preserves_the_core_currency_resource_without_an_fx_rate_adapter_type
    payload = JSON.generate(
      "data" => [
        {
          "type" => "currency",
          "id" => "uah",
          "attributes" => {
            "code" => "UAH",
            "usdt_per_unit" => "0.024"
          }
        }
      ]
    )
    api = api_with(response("200", payload))

    currency = api.currencies(locale: "uk_UA").first

    assert_equal "currency", currency.fetch("type")
    assert_equal "uah", currency.fetch("id")
    assert_equal "UAH", currency.dig("attributes", "code")
    assert_equal "/v1/currencies", api.uris.first.path
    assert_equal "locale=uk_UA", api.uris.first.query
    refute_respond_to api, :fx_rates
    refute_respond_to api, :set_fx_rates
  end

  def test_translates_telegram_authentication_to_external_identity_contract
    api = api_with(
      response(
        "201",
        '{"data":{"id":"user-1","attributes":{"role":"client","identity":{"provider":"telegram"}}}}'
      )
    )

    user = api.authenticate_telegram(
      user: {
        "id" => 77,
        "username" => "zero",
        "first_name" => "Sasha",
        "language_code" => "uk"
      },
      chat: { "id" => 770 }
    )

    assert_equal "user-1", user.fetch("id")
    assert_equal "/v1/auth/external", api.uris.first.path
    body = JSON.parse(api.requests.first.body)
    assert_equal "telegram", body.fetch("provider")
    assert_equal "77", body.fetch("provider_user_id")
    assert_equal "770", body.dig("provider_data", "chat_id")
    assert_equal "zero", body.dig("provider_data", "username")
    refute body.fetch("provider_data").key?("last_name")
  end

  def test_adapts_generic_profiles_for_telegram_ui
    api = api_with(response("200", generic_users_payload))

    user = api.active_users.first
    attributes = user.fetch("attributes")

    assert_equal "user-1", user.fetch("id")
    assert_equal "77", attributes.fetch("telegram_user_id")
    assert_equal "770", attributes.fetch("telegram_chat_id")
    assert_equal "zero", attributes.fetch("telegram_username")
    assert_equal "uk", attributes.fetch("language_code")
    assert_equal "telegram", attributes.fetch("identities").first.fetch("provider")
  end

  def test_forwards_internal_actor_uuid_without_loading_active_users
    api = api_with(
      response("201", '{"data":[{"id":"premium_3m","attributes":{"amount_usdt":"12.50"}}]}')
    )

    applied = api.apply_prices(
      actor_user_id: "user-1",
      prices: [{ sku: "premium_3m", amount_usdt: "12.50" }]
    )

    assert_equal "premium_3m", applied.first.fetch("id")
    assert_equal 1, api.attempts
    assert_equal ["/v1/admin/prices"], api.uris.map(&:path)
    body = JSON.parse(api.requests.first.body)
    assert_equal "user-1", body.fetch("actor_user_id")
    refute body.key?("actor_telegram_user_id")
  end

  def test_resolves_a_telegram_username_without_loading_active_users
    target = generic_user(id: "target-1", telegram_id: "78", username: "Target_User")
    api = api_with(
      response("200", generic_user_payload(user: target)),
      response("200", '{"data":{"id":"target-1","attributes":{"role":"admin"},"meta":{"changed":true}}}')
    )

    assignment = api.set_admin(actor_user_id: "owner-1", target: "@target_user")

    assert_equal 2, api.attempts
    assert_equal(
      ["/v1/admin/users/by-external-identity", "/v1/admin/users/set-admin"],
      api.uris.map(&:path)
    )
    query = URI.decode_www_form(api.uris.first.query).to_h
    assert_equal "owner-1", query.fetch("actor_user_id")
    assert_equal "telegram", query.fetch("provider")
    assert_equal "username", query.fetch("provider_data_key")
    assert_equal "target_user", query.fetch("provider_data_value")
    assert_equal "true", query.fetch("case_insensitive")
    refute query.key?("provider_user_id")

    body = JSON.parse(api.requests.last.body)
    assert_equal "owner-1", body.fetch("actor_user_id")
    assert_equal "target-1", body.fetch("target_user_id")
    assert_equal "78", assignment.dig("attributes", "telegram_user_id")
    assert_equal "780", assignment.dig("attributes", "telegram_chat_id")
    assert_equal "admin", assignment.dig("attributes", "role")
  end

  def test_resolves_a_telegram_user_id_without_loading_active_users
    target = generic_user(id: "target-1", telegram_id: "78", username: "target")
    api = api_with(
      response("200", generic_user_payload(user: target)),
      response("200", '{"data":{"id":"target-1","attributes":{"role":"admin"},"meta":{"changed":true}}}')
    )

    api.set_admin(actor_user_id: "owner-1", target: "78")

    query = URI.decode_www_form(api.uris.first.query).to_h
    assert_equal "78", query.fetch("provider_user_id")
    refute query.key?("provider_data_key")
    assert_equal [
      "/v1/admin/users/by-external-identity",
      "/v1/admin/users/set-admin"
    ], api.uris.map(&:path)
  end

  def test_rejects_an_ambiguous_admin_target_before_an_api_request
    api = api_with

    error = assert_raises(ArgumentError) do
      api.set_admin(actor_user_id: "owner-1", target: "target_user")
    end

    assert_includes error.message, "@username or Telegram user ID"
    assert_equal 0, api.attempts
  end

  def test_retries_gateway_errors
    %w[502 503 504].each do |status|
      api = api_with(response(status, "<html>starting</html>"), json_response)

      assert_equal({ "status" => "ok" }, api.health)
      assert_equal 2, api.attempts
    end
  end

  def test_retries_a_temporary_non_json_response
    api = api_with(response("200", "<html>starting</html>"), json_response)

    assert_equal({ "status" => "ok" }, api.health)
    assert_equal 2, api.attempts
  end

  def test_uses_exponential_backoff_until_the_market_recovers
    failures = Array.new(5) { Timeout::Error.new("cold start") }
    api = api_with(*failures, json_response)

    assert_equal({ "status" => "ok" }, api.health)
    assert_equal [2, 4, 8, 16, 30], api.backoffs
  end

  def test_wraps_the_error_after_retry_is_exhausted
    api = api_with(*Array.new(6) { Timeout::Error.new("cold start") })

    error = assert_raises(ZeroXDA::MarketClientBot::MarketAPI::Error) { api.health }

    assert_includes error.message, "cold start"
    assert_equal 6, api.attempts
  end

  private

  def api_with(*outcomes)
    StubbedMarketAPI.new(
      outcomes: outcomes,
      base_url: "https://market.example",
      token: "token"
    )
  end

  def generic_users_payload(users: [generic_user])
    JSON.generate("data" => users)
  end

  def generic_user_payload(user: generic_user)
    JSON.generate("data" => user)
  end

  def generic_user(id: "user-1", telegram_id: "77", username: "zero")
    {
      "id" => id,
      "attributes" => {
        "role" => username == "owner" ? "admin" : "client",
        "status" => "active",
        "identities" => [
          {
            "provider" => "telegram",
            "provider_user_id" => telegram_id,
            "provider_data" => {
              "chat_id" => "#{telegram_id}0",
              "username" => username,
              "language_code" => "uk"
            }
          }
        ]
      }
    }
  end

  def json_response
    response("200", '{"status":"ok"}')
  end

  def response(status, body)
    response_class = {
      "200" => Net::HTTPOK,
      "201" => Net::HTTPCreated,
      "502" => Net::HTTPBadGateway,
      "503" => Net::HTTPServiceUnavailable,
      "504" => Net::HTTPGatewayTimeout
    }.fetch(status)
    value = response_class.new("1.1", status, "response")
    value.instance_variable_set(:@read, true)
    value.instance_variable_set(:@body, body)
    value
  end
end
