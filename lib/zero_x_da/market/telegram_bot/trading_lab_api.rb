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

    # Read-only leaderboard filters forwarded to Trading Lab, which validates their values.
    LEADER_OPTIONS = %w[sort state min_lead_days min_assets max_assets min_aum max_aum data_version page limit].freeze
    LEADER_VALUE = /\A[A-Za-z0-9_]{1,32}\z/

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

      uri = endpoint("/v1/paper/replays")
      request = Net::HTTP::Post.new(uri.request_uri)
      request["content-type"] = "application/json"
      request.body = body
      perform(uri, request, "replay")
    end

    # Public OKX lead trader leaderboard via Trading Lab. Paper research only: no copy or order action.
    def leaders(options: {})
      raise ArgumentError, "options must be an object" unless options.is_a?(Hash)
      options = options.transform_keys(&:to_s)
      raise ArgumentError, "unknown leaderboard option" unless (options.keys - LEADER_OPTIONS).empty?
      options.each_value { |value| raise ArgumentError, "invalid leaderboard option" unless LEADER_VALUE.match?(value.to_s) }

      uri = endpoint("/v1/leaders/okx")
      uri.query = URI.encode_www_form(options.sort) unless options.empty?
      perform(uri, Net::HTTP::Get.new(uri.request_uri), "leaderboard")
    end

    private

    # Trading Lab 422 messages describe the caller's own filters (e.g. "limit must be between 1 and 20").
    # Pass through only short plain text; anything else falls back to a generic message.
    def safe_message(document)
      message = document.is_a?(Hash) ? document["message"] : nil
      message if message.is_a?(String) && message.match?(/\A[\w .,:()<>=-]{1,120}\z/)
    end

    def endpoint(path)
      uri = @base.dup
      uri.path = "#{@base.path.delete_suffix("/")}#{path}"
      uri
    end

    def perform(uri, request, label)
      request["authorization"] = "Bearer #{@token}"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 8) do |http|
        http.request(request)
      end
      document = JSON.parse(response.body)
      raise ArgumentError, safe_message(document) || "invalid #{label} request" if response.code == "422"
      raise Error, "Trading Lab #{label} is unavailable (HTTP #{response.code})" unless response.code == "200" && document["status"] == "ok" && document["data"].is_a?(Hash)
      document.fetch("data")
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "Trading Lab #{label} is unavailable (#{error.class})"
    end
  end
end
