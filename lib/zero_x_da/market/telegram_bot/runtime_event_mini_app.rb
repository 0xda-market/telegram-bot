# frozen_string_literal: true

require_relative "namespace"

require "json"
require "rack"

module ZeroXDA::Market::TelegramBot
  class RuntimeEventMiniApp
    JSON_HEADERS = {
      "content-type" => "application/json; charset=utf-8",
      "cache-control" => "no-store"
    }.freeze

    def initialize(app:, authentication:, notifier:, environment:)
      @app = app
      @authentication = authentication
      @notifier = notifier
      @environment = environment.to_s
    end

    def call(environment)
      request = Rack::Request.new(environment)
      return @app.call(environment) unless request.post? && request.path_info == "/webapp/runtime-events"

      session = @authentication.verify(request.get_header("HTTP_X_TELEGRAM_INIT_DATA").to_s)
      body = request.body.read(4097)
      raise ArgumentError, "request body is too large" if body.bytesize > 4096
      event = JSON.parse(body)
      raise ArgumentError, "runtime event must be an object" unless event.is_a?(Hash)

      @notifier.deliver(event: event, subject: session.subject, environment: @environment)
      [202, JSON_HEADERS, [JSON.generate("status" => "ok")]]
    rescue TelegramWebAppAuth::Invalid => error
      [401, JSON_HEADERS, [JSON.generate("status" => "error", "error" => "invalid_telegram_session", "message" => error.message)]]
    rescue JSON::ParserError, ArgumentError => error
      [422, JSON_HEADERS, [JSON.generate("status" => "error", "error" => "invalid_runtime_event", "message" => error.message)]]
    end
  end
end
