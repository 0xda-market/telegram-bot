# frozen_string_literal: true

module ZeroXDA
  module TelegramBot
    class TelegramBotIdentity
      USERNAME_PATTERN = /\A[A-Za-z][A-Za-z0-9_]{4,31}\z/

      class << self
        def resolve(configured_username:, telegram_api:)
          username = normalize(configured_username)
          username = normalize(telegram_api.get_me.fetch("username")) if username.empty?
          validate!(username)
        rescue KeyError
          raise ArgumentError, "Telegram bot username is missing"
        end

        def validate!(username)
          normalized = normalize(username)
          raise ArgumentError, "Telegram bot username is invalid" unless USERNAME_PATTERN.match?(normalized)

          normalized
        end

        private

        def normalize(value)
          value.to_s.strip.delete_prefix("@")
        end
      end
    end
  end
end
