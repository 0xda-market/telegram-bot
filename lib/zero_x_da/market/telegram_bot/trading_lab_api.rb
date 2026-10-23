# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "namespace"

module ZeroXDA::Market::TelegramBot
  # Server-only adapter to a private, paper-only Trading Lab service.
  class TradingLabAPI
    class Error < StandardError; end

    def initialize(origin:, token:)
      @base = URI.parse(origin.to_s)
      raise ArgumentError, "Trading Lab origin must not include credentials or a query" if @base.userinfo || @base.query || @base.fragment
      local = %w[127.0.0.1 localhost ::1].include?(@base.hostname)
      docker_service = @base.hostname == "market-trading-lab" && @base.port == 1927 && @base.path.match?(%r{\A/?\z})
      raise ArgumentError, "Trading Lab origin must use HTTPS outside approved private hosts" unless
        @base.scheme == "https" || (@base.scheme == "http" && (local || docker_service))
      raise ArgumentError, "Trading Lab token is required" if token.to_s.strip.empty?
      @token = token.to_s
    end

    def replay(events:, options: {})
      raise ArgumentError, "events must contain at most 500 records" unless events.is_a?(Array) && events.size <= 500
      raise ArgumentError, "options must be an object" unless options.is_a?(Hash)
      body = JSON.generate(events: events, options: options)
      raise ArgumentError, "paper replay request is too large" if body.bytesize > 65_536

      uri = @base.dup
      uri.path = "#{@base.path.delete_suffix("/")}/v1/paper/replays"
      request = Net::HTTP::Post.new(uri.request_uri)
      request["authorization"] = "Bearer #{@token}"
      request["content-type"] = "application/json"
      request.body = body
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 8) do |http|
        http.request(request)
      end
      document = JSON.parse(response.body)
      raise Error, "Trading Lab replay is unavailable (HTTP #{response.code})" unless response.code == "200" && document["status"] == "ok" && document["data"].is_a?(Hash)
      document.fetch("data")
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "Trading Lab replay is unavailable (#{error.class})"
    end
  end
end
