# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"
require "rack/mock"
require "tmpdir"
require "zero_x_da/market/telegram_bot/recipient_picker_mini_app"

class RecipientPickerMiniAppTest < Minitest::Test
  class Service
    attr_reader :requests

    def initialize
      @requests = []
    end

    def prepare_recipient_picker(init_data:)
      @requests << [:prepare, init_data]
      {
        "data" => {
          "token" => "a" * 32,
          "prepared_id" => "prepared-1",
          "expires_at" => "2026-08-08T07:02:00Z"
        }
      }
    end

    def recipient_picker_result(init_data:, token:)
      @requests << [:result, init_data, token]
      {
        "data" => {
          "status" => "selected",
          "recipient" => { "user_id" => "88", "name" => "Ada", "username" => "ada" }
        }
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

  def test_prepares_and_reads_native_recipient_picker_state
    prepared = @client.post(
      "/webapp/recipient-picker",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data",
      "CONTENT_TYPE" => "application/json",
      input: "{}"
    )
    selected = @client.get(
      "/webapp/recipient-picker/#{"a" * 32}",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )

    assert_equal 201, prepared.status
    assert_equal "ok", JSON.parse(prepared.body).fetch("status")
    assert_equal "prepared-1", JSON.parse(prepared.body).dig("data", "prepared_id")
    assert_equal 200, selected.status
    assert_equal "ada", JSON.parse(selected.body).dig("data", "recipient", "username")
    assert_equal(
      [[:prepare, "signed-init-data"], [:result, "signed-init-data", "a" * 32]],
      @service.requests
    )
  end

  def test_rejects_invalid_picker_tokens_before_service_lookup
    response = @client.get(
      "/webapp/recipient-picker/not-a-token",
      "HTTP_X_TELEGRAM_INIT_DATA" => "signed-init-data"
    )

    assert_equal 422, response.status
    assert_equal "invalid_request", JSON.parse(response.body).fetch("error")
    assert_empty @service.requests
  end
end
