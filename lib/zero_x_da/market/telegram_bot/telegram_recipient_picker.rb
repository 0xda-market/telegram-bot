# frozen_string_literal: true

require_relative "namespace"

require "securerandom"
require "time"

module ZeroXDA::Market::TelegramBot
  class TelegramRecipientPicker
    DEFAULT_TTL_SECONDS = 120
    REQUEST_ID_MAX = (2**31) - 1

    def initialize(telegram_api:, clock: -> { Time.now.utc }, ttl_seconds: DEFAULT_TTL_SECONDS)
      @telegram_api = telegram_api
      @clock = clock
      @ttl_seconds = Integer(ttl_seconds)
      @mutex = Mutex.new
      @requests = {}
      @request_index = {}
    end

    def prepare(requester_id:)
      requester_id = Integer(requester_id)
      token = SecureRandom.hex(16)
      request_id = next_request_id(requester_id)
      expires_at = @clock.call + @ttl_seconds

      @mutex.synchronize do
        cleanup_locked
        @requests[token] = {
          requester_id: requester_id,
          request_id: request_id,
          expires_at: expires_at,
          selected: nil
        }
        @request_index[[requester_id, request_id]] = token
      end

      prepared = @telegram_api.save_prepared_keyboard_button(
        user_id: requester_id,
        button: {
          text: "Choose recipient",
          request_users: {
            request_id: request_id,
            user_is_bot: false,
            max_quantity: 1,
            request_name: true,
            request_username: true,
            request_photo: false
          }
        }
      )

      {
        "token" => token,
        "prepared_id" => prepared.fetch("id"),
        "expires_at" => expires_at.iso8601(6)
      }
    rescue StandardError
      @mutex.synchronize { delete_locked(token) } if token
      raise
    end

    def capture(update)
      message = update["message"]
      shared = message&.dig("users_shared")
      return false unless shared

      requester_id = Integer(message.fetch("from").fetch("id"))
      request_id = Integer(shared.fetch("request_id"))
      selected = Array(shared["users"]).first
      return false unless selected

      @mutex.synchronize do
        cleanup_locked
        token = @request_index[[requester_id, request_id]]
        return false unless token

        entry = @requests[token]
        return false unless entry

        entry[:selected] = normalize_selected_user(selected)
      end
      true
    rescue KeyError, ArgumentError, TypeError
      false
    end

    def result(token:, requester_id:)
      requester_id = Integer(requester_id)
      @mutex.synchronize do
        cleanup_locked
        entry = @requests[token.to_s]
        return { "status" => "expired" } unless entry && entry[:requester_id] == requester_id
        return { "status" => "pending" } unless entry[:selected]

        { "status" => "selected", "recipient" => entry[:selected] }
      end
    end

    private

    def next_request_id(requester_id)
      loop do
        candidate = SecureRandom.random_number(REQUEST_ID_MAX) + 1
        return candidate unless @mutex.synchronize { @request_index.key?([requester_id, candidate]) }
      end
    end

    def normalize_selected_user(user)
      first_name = user["first_name"].to_s.strip
      last_name = user["last_name"].to_s.strip
      name = [first_name, last_name].reject(&:empty?).join(" ")
      {
        "user_id" => Integer(user.fetch("user_id")).to_s,
        "name" => name.empty? ? nil : name,
        "username" => user["username"].to_s.sub(/\A@/, "").presence
      }.compact
    end

    def cleanup_locked
      now = @clock.call
      @requests.each_key.to_a.each do |token|
        delete_locked(token) if @requests.fetch(token)[:expires_at] <= now
      end
    end

    def delete_locked(token)
      entry = @requests.delete(token)
      return unless entry

      @request_index.delete([entry[:requester_id], entry[:request_id]])
    end
  end
end
