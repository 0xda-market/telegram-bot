# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: MIT
# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "time"
require "uri"

module ZeroXDA::Market::TelegramBot
  # Noncritical, bounded public errors.v1 producer. No collector token or DB credentials.
  # No collector config => null reporter; errors never affect checkout or paper trading.
  class ErrorsReporter
    MAX_PENDING = 32
    STOP = Object.new.freeze

    def self.from_env
      endpoint = ENV.fetch("FOUR_X_ERRORS_URL", "")
      return nil if endpoint.empty?
      public_url = URI.parse(ENV.fetch("PUBLIC_URL"))
      origin = "#{public_url.scheme}://#{public_url.host}"
      origin += ":#{public_url.port}" unless public_url.default_port == public_url.port
      new(endpoint: endpoint, origin: origin)
    rescue ArgumentError, URI::InvalidURIError
      nil
    end

    def initialize(endpoint:, origin:, transport: nil)
      @uri = URI.parse(endpoint)
      local = %w[localhost 127.0.0.1 ::1].include?(@uri.hostname)
      valid_scheme = @uri.scheme == "https" || (local && @uri.scheme == "http")
      raise ArgumentError, "collector requires HTTPS" unless valid_scheme
      raise ArgumentError, "collector origin must be bare" if @uri.userinfo || @uri.query || @uri.fragment ||
                                                             !["", "/"].include?(@uri.path)
      @origin = URI.parse(origin)
      raise ArgumentError, "source origin must be a bare HTTPS origin" unless
        @origin.scheme == "https" && @origin.host && @origin.userinfo.nil? &&
        @origin.query.nil? && @origin.fragment.nil? && ["", "/"].include?(@origin.path)
      @uri.path = "/v1/browser/events"
      @queue = SizedQueue.new(MAX_PENDING)
      @transport = transport || method(:deliver)
      @worker = Thread.new do
        Thread.current.report_on_exception = false
        loop do
          event = @queue.pop
          break if event.equal?(STOP)
          begin
            @transport.call(event)
          rescue StandardError
            # Telemetry must not be an application dependency. No retry storm.
          end
        end
      end
    end

    def report(error_id:, message:, context:, correlation_id: nil, severity: "error")
      event = {
        protocol_version: "errors.v1", event_id: SecureRandom.uuid,
        error_id: error_id, project: "0xda-market/telegram-bot",
        source: "trading-lab-api", severity: severity,
        message: message, full_text: message,
        observed_at: Time.now.utc.iso8601(3),
        context: context, tags: ["paper-trading"]
      }
      if correlation_id.is_a?(String) && /\A[0-9a-f-]{36}\z/i.match?(correlation_id)
        event[:correlation_id] = correlation_id
      end
      @queue.push(event, true)
      true
    rescue StandardError
      false
    end

    # Allows deterministic shutdown in tests; production worker is process-scoped.
    def stop
      @queue.push(STOP)
      @worker.join(2)
    end

    private

    def deliver(event)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request["content-type"] = "application/json"
      request["origin"] = @origin.to_s.delete_suffix("/")
      request.body = JSON.generate(event)
      Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https",
                      open_timeout: 0.5, read_timeout: 0.8, write_timeout: 0.5) do |http|
        http.request(request)
      end
    end
  end
end
