require_relative "test_helper"
require "json"
require "rack/mock"
require "zero_x_da/market_client_bot/bot_identity"
require "zero_x_da/market_client_bot/http_app"
require "zero_x_da/market_client_bot/web_app"

class HTTPAppTest < Minitest::Test
  class ImmediateDispatcher
    def call(&task)
      task.call
    end
  end

  class HoldingDispatcher
    attr_reader :task

    def call(&task)
      @task = task
    end
  end

  class Handler
    attr_reader :updates

    def initialize
      @updates = []
    end

    def handle(update)
      @updates << update
    end
  end

  class TelegramIdentity
    attr_reader :requests

    def initialize(username: "market_development_bot")
      @username = username
      @requests = 0
    end

    def get_me
      @requests += 1
      { "username" => @username }
    end
  end

  def setup
    @handler = Handler.new
    @telegram_identity = TelegramIdentity.new
    @client = Rack::MockRequest.new(build_app(username: "market_development_bot"))
  end

  def test_root_redirects_to_the_boot_resolved_bot_without_a_telegram_request
    2.times do
      response = @client.get("/")

      assert_equal 302, response.status
      assert_equal "https://t.me/market_development_bot", response["location"]
      assert_equal "no-store", response["cache-control"]
    end

    assert_equal 0, @telegram_identity.requests
  end

  def test_bot_identity_is_resolved_from_get_me_once_before_http_requests
    username = ZeroXDA::MarketClientBot::TelegramBotIdentity.resolve(
      configured_username: nil,
      telegram_api: @telegram_identity
    )
    client = Rack::MockRequest.new(build_app(username: username))

    2.times { client.get("/") }

    assert_equal 1, @telegram_identity.requests
  end

  def test_configured_bot_identity_skips_get_me_and_normalizes_the_at_prefix
    username = ZeroXDA::MarketClientBot::TelegramBotIdentity.resolve(
      configured_username: "@market_development_bot",
      telegram_api: @telegram_identity
    )

    assert_equal "market_development_bot", username
    assert_equal 0, @telegram_identity.requests
  end

  def test_invalid_bot_identity_fails_during_boot
    error = assert_raises(ArgumentError) do
      ZeroXDA::MarketClientBot::TelegramBotIdentity.resolve(
        configured_username: "invalid username",
        telegram_api: @telegram_identity
      )
    end

    assert_includes error.message, "username is invalid"
  end

  def test_legacy_web_app_constant_aliases_the_http_app
    assert_equal ZeroXDA::MarketClientBot::HTTPApp, ZeroXDA::MarketClientBot::WebApp
  end

  def test_health_is_public_and_includes_server_time
    response = @client.get("/health")

    assert_equal 200, response.status
    document = JSON.parse(response.body)
    assert_equal "ok", document.fetch("status")
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, document.fetch("server_time"))
    assert_equal "test-revision", document.fetch("revision")
  end

  def test_rejects_a_webhook_without_the_telegram_secret
    response = @client.post(
      "/telegram/webhook",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(update_id: 1)
    )

    assert_equal 401, response.status
    assert_empty @handler.updates
  end

  def test_accepts_and_dispatches_a_verified_webhook
    response = @client.post(
      "/telegram/webhook",
      "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN" => "webhook-secret",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(update_id: 1, message: { text: "/start" })
    )

    assert_equal 200, response.status
    assert_equal 1, @handler.updates.first.fetch("update_id")
  end

  def test_acknowledges_the_webhook_before_processing_the_update
    dispatcher = HoldingDispatcher.new
    client = Rack::MockRequest.new(build_app(username: "market_development_bot", dispatcher: dispatcher))

    response = client.post(
      "/telegram/webhook",
      "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN" => "webhook-secret",
      "CONTENT_TYPE" => "application/json",
      input: JSON.generate(update_id: 2, message: { text: "/start" })
    )

    assert_equal 200, response.status
    assert_empty @handler.updates

    dispatcher.task.call
    assert_equal 2, @handler.updates.first.fetch("update_id")
  end

  private

  def build_app(username:, dispatcher: ImmediateDispatcher.new)
    ZeroXDA::MarketClientBot::HTTPApp.new(
      bot: @handler,
      webhook_secret: "webhook-secret",
      telegram_username: username,
      dispatcher: dispatcher,
      revision: "test-revision"
    )
  end
end
