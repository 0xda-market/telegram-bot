# frozen_string_literal: true

require_relative "namespace"
require_relative "market_api"

module ZeroXDA::Market::TelegramBot
  class MarketAPI
    PAYMENT_OPEN_TIMEOUT = 2
    PAYMENT_READ_TIMEOUT = 5

    private

    # Payment webhooks should not spend the generic API client's long retry
    # budget. One bounded attempt lets the webhook fail quickly and rely on the
    # provider's authoritative event retry plus core charge idempotency.
    def payment_confirmation_post(path, payload)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["authorization"] = "Bearer #{@token}"
      request["content-type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        http.open_timeout = PAYMENT_OPEN_TIMEOUT
        http.read_timeout = PAYMENT_READ_TIMEOUT
        http.request(request)
      end
      document = JSON.parse(response.body)
      return document if response.is_a?(Net::HTTPSuccess)

      failure = document.fetch("errors", [{}]).first
      raise Error.new(
        failure["message"] || "Market API payment confirmation failed",
        code: failure["code"] || response.code,
        status: response.code.to_i
      )
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error => error
      raise Error.new(
        "Market API payment confirmation failed: #{error.message}",
        code: "payment_confirmation_transport_error",
        status: 503
      )
    end
  end
end
