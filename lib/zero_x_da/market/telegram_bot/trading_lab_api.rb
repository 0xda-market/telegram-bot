# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "securerandom"
require "openssl"
require_relative "namespace"

module ZeroXDA::Market::TelegramBot
  # Server-only adapter to a private, paper-only Trading Lab service.
  class TradingLabAPI
    # `code` is the stable, locale-free reason the Mini App turns into user text. The message is an
    # English fallback only: it never carries an HTTP status or an exception class, which belong to
    # the correlated runtime log.
    class Error < StandardError
      UNAVAILABLE = "trading_lab_unavailable"
      TIMEOUT = "trading_lab_timeout"

      attr_reader :code

      def initialize(message = nil, code: UNAVAILABLE)
        super(message)
        @code = code
      end
    end

    # A job endpoint answered with a named, user-meaningful state (busy or expired).
    class JobError < Error
      attr_reader :status

      def initialize(status, code)
        @status = status
        super(code, code: code)
      end
    end

    # Read-only leaderboard filters forwarded to Trading Lab, which validates their values.
    LEADER_OPTIONS = %w[sort state min_lead_days min_assets max_assets min_aum max_aum data_version page limit].freeze
    LEADER_VALUE = /\A[A-Za-z0-9_]{1,32}\z/

    def initialize(origin:, token:, logger: $stderr)
      @base = URI.parse(origin.to_s)
      raise ArgumentError, "Trading Lab origin must not include credentials or a query" if @base.userinfo || @base.query || @base.fragment
      local = %w[127.0.0.1 localhost ::1].include?(@base.hostname)
      # Private infra aliases on nilx-edge: production (1927) and development (1703).
      docker_service = { "market-trading-lab" => 1927, "market-trading-lab-development" => 1703 }[@base.hostname] == @base.port &&
                       @base.path.match?(%r{\A/?\z})
      raise ArgumentError, "Trading Lab origin must use HTTPS outside approved private hosts" unless
        @base.scheme == "https" || (@base.scheme == "http" && (local || docker_service))
      raise ArgumentError, "Trading Lab token is required" if token.to_s.strip.empty?
      @token = token.to_s
      @logger = logger
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

    # Paper copy of one OKX lead trader's real closed positions; no copy or order action.
    # Trading Lab may read up to 3 throttled OKX pages, so this call allows a longer read,
    # still below the Mini App transport timeout (15 s).
    def copy_replay(unique_code:, options: {})
      raise ArgumentError, "unique_code is invalid" unless unique_code.is_a?(String) && unique_code.match?(/\A(?:[0-9A-Za-z]{16}|[0-9]{18})\z/)
      raise ArgumentError, "options must be an object" unless options.is_a?(Hash)
      body = JSON.generate(unique_code: unique_code, options: options)
      raise ArgumentError, "copy replay request is too large" if body.bytesize > 4096

      uri = endpoint("/v1/paper/copy-replays")
      request = Net::HTTP::Post.new(uri.request_uri)
      request["content-type"] = "application/json"
      request.body = body
      perform(uri, request, "copy replay", read_timeout: 12)
    end

    def start_copy_replay(unique_code:, options: {}, owner:)
      raise ArgumentError, "unique_code is invalid" unless unique_code.is_a?(String) && unique_code.match?(/\A(?:[0-9A-Za-z]{16}|[0-9]{18})\z/)
      raise ArgumentError, "options must be an object" unless options.is_a?(Hash)
      body = JSON.generate(unique_code: unique_code, options: options)
      raise ArgumentError, "copy replay request is too large" if body.bytesize > 4096
      uri = endpoint("/v1/paper/copy-replay-jobs")
      request = Net::HTTP::Post.new(uri.request_uri)
      request["content-type"] = "application/json"
      request["x-trading-replay-owner"] = owner_reference(owner)
      request.body = body
      perform(uri, request, "copy job submit", accepted_status: "202", job_errors: true)
    end

    def copy_replay_job(job_id:, owner:)
      raise ArgumentError, "invalid job id" unless job_id.is_a?(String) && job_id.match?(/\A[0-9a-f]{32}\z/)
      uri = endpoint("/v1/paper/copy-replay-jobs/#{job_id}")
      request = Net::HTTP::Get.new(uri.request_uri)
      request["x-trading-replay-owner"] = owner_reference(owner)
      perform(uri, request, "copy job status", job_errors: true)
    end

    private

    def owner_reference(owner)
      raise ArgumentError, "invalid replay owner" if owner.to_s.empty?
      OpenSSL::HMAC.hexdigest("SHA256", @token, "copy-replay-owner:v1:#{owner}")
    end

    # Trading Lab 422 messages describe the caller's own filters (e.g. "limit must be between 1 and 20").
    # Pass through only short plain text; anything else falls back to a generic message.
    def safe_message(document)
      message = document.is_a?(Hash) ? document["message"] : nil
      message if message.is_a?(String) && message.match?(/\A[\w .,:;()<>=-]{1,120}\z/)
    end

    def endpoint(path)
      uri = @base.dup
      uri.path = "#{@base.path.delete_suffix("/")}#{path}"
      uri
    end

    def perform(uri, request, label, read_timeout: 8, accepted_status: "200", job_errors: false)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      correlation_id = SecureRandom.uuid
      request["authorization"] = "Bearer #{@token}"
      request["x-correlation-id"] = correlation_id
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: read_timeout) do |http|
        http.request(request)
      end
      document = JSON.parse(response.body)
      if response.code == "422"
        report_failure("market.trading.request.rejected", "Trading Lab rejected a paper request", label,
                       started, correlation_id, severity: "warning", upstream_status: 422)
        raise ArgumentError, safe_message(document) || "invalid #{label} request"
      end
      if job_errors && document.is_a?(Hash)
        code = document["error"]
        raise JobError.new(404, code) if response.code == "404" && code == "copy_job_not_found"
        raise JobError.new(503, code) if response.code == "503" && code == "copy_jobs_busy"
      end
      unless response.code == accepted_status && document.is_a?(Hash) && document["status"] == "ok" && document["data"].is_a?(Hash)
        report_failure("market.trading.upstream.unavailable", "Trading Lab returned an unsuccessful response", label,
                       started, correlation_id, upstream_status: response.code.to_i)
        raise Error, "Trading Lab #{label} is unavailable"
      end
      document.fetch("data")
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
      report_failure("market.trading.transport.failed", "Trading Lab transport or response failed", label,
                     started, correlation_id, exception_type: error.class.name.split("::").last)
      if error.is_a?(Timeout::Error)
        raise Error.new("Trading Lab #{label} did not respond in time", code: Error::TIMEOUT)
      end
      raise Error, "Trading Lab #{label} is unavailable"
    end

    # Keep request data and credentials out of logs. Record only a fixed
    # operation name, the correlation ID and bounded diagnostic metadata.
    def report_failure(error_id, message, label, started, correlation_id, severity: "error", **details)
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      @logger&.puts(JSON.generate(
        error_id: error_id, message: message, severity: severity, correlation_id: correlation_id,
        context: { operation: label.tr(" ", "_"), elapsed_ms: elapsed_ms }.merge(details)
      ))
    rescue StandardError
      nil
    end
  end
end
