# frozen_string_literal: true

require_relative "namespace"

require "digest"
require "time"

module ZeroXDA::Market::TelegramBot
  class RuntimeEventNotifier
    WINDOW_SECONDS = 900

    def initialize(market_api:, telegram_api:, clock: -> { Time.now.utc })
      @market_api = market_api
      @telegram_api = telegram_api
      @clock = clock
      @delivered = {}
      @mutex = Mutex.new
    end

    def deliver(event:, subject:, environment:)
      normalized = normalize(event)
      return false unless normalized.fetch("type") == "startup_failed"
      return false unless claim(normalized, environment)

      text = [
        "⚠️ 0xda-market Mini App startup failed",
        "environment: #{environment}",
        "subject: #{subject}",
        "message: #{normalized.fetch("message")}",
        "revision: #{normalized["revision"] || "unknown"}",
        "time: #{@clock.call.iso8601(6)}"
      ].join("\n")

      active_admins.each do |admin|
        telegram_user_id = admin.dig("attributes", "telegram_user_id")
        next unless telegram_user_id

        @telegram_api.send_message(chat_id: telegram_user_id, text: text, reply_markup: nil)
      rescue StandardError => error
        warn "runtime event notification for #{telegram_user_id} failed: #{error.message}"
      end
      true
    end

    private

    def normalize(event)
      source = event.is_a?(Hash) ? event : {}
      {
        "type" => source["type"].to_s[0, 80],
        "message" => source["message"].to_s[0, 500],
        "revision" => source["revision"].to_s[0, 80]
      }
    end

    def claim(event, environment)
      now = @clock.call.to_i
      key = Digest::SHA256.hexdigest([environment, event["type"], event["message"], event["revision"]].join("\0"))
      @mutex.synchronize do
        @delivered.delete_if { |_fingerprint, delivered_at| delivered_at <= now - WINDOW_SECONDS }
        return false if @delivered.key?(key)

        @delivered[key] = now
        true
      end
    end

    def active_admins
      @market_api.active_users.select do |user|
        user.dig("attributes", "role") == "admin" &&
          user.dig("attributes", "status") == "active"
      end
    end
  end
end
