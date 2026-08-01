# frozen_string_literal: true

require "json"
require "openssl"
require "uri"

module ZeroXDA
  module TelegramBot
    class TelegramWebAppAuth
      Session = Struct.new(:user, :chat, :auth_date, :query_id, keyword_init: true)

      class Invalid < StandardError; end

      def initialize(bot_token:, max_age_seconds: 3600, clock: -> { Time.now.utc })
        raise ArgumentError, "Telegram bot token must not be empty" if bot_token.to_s.empty?

        @bot_token = bot_token.to_s
        @max_age_seconds = Integer(max_age_seconds)
        raise ArgumentError, "Telegram WebApp auth max age must be positive" unless @max_age_seconds.positive?

        @clock = clock
      end

      def verify(init_data)
        fields = parse(init_data)
        received_hash = fields.delete("hash").to_s
        fields.delete("signature")
        raise Invalid, "Telegram WebApp hash is missing" unless received_hash.match?(/\A[0-9a-f]{64}\z/i)

        data_check_string = fields.sort.map { |key, value| "#{key}=#{value}" }.join("\n")
        secret_key = OpenSSL::HMAC.digest("SHA256", "WebAppData", @bot_token)
        expected_hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)
        raise Invalid, "Telegram WebApp signature is invalid" unless secure_compare(received_hash.downcase, expected_hash)

        auth_date = Integer(fields.fetch("auth_date"), 10)
        age = @clock.call.to_i - auth_date
        raise Invalid, "Telegram WebApp data is from the future" if age < -30
        raise Invalid, "Telegram WebApp data has expired" if age > @max_age_seconds

        user = parse_object(fields.fetch("user"), field: "user")
        raise Invalid, "Telegram WebApp user id is missing" if user["id"].to_s.empty?

        chat = fields["chat"] ? parse_object(fields.fetch("chat"), field: "chat") : nil
        chat ||= { "id" => user.fetch("id"), "type" => "private" }

        Session.new(
          user: user,
          chat: chat,
          auth_date: Time.at(auth_date).utc,
          query_id: fields["query_id"]
        )
      rescue ArgumentError, KeyError, TypeError, JSON::ParserError => error
        raise Invalid, error.message
      end

      private

      def parse(init_data)
        value = init_data.to_s
        raise Invalid, "Telegram WebApp init data is missing" if value.empty?

        pairs = URI.decode_www_form(value)
        fields = {}
        pairs.each do |key, field_value|
          raise Invalid, "Telegram WebApp field is duplicated: #{key}" if fields.key?(key)

          fields[key] = field_value
        end
        fields
      rescue ArgumentError => error
        raise Invalid, "Telegram WebApp init data is malformed: #{error.message}"
      end

      def parse_object(value, field:)
        document = JSON.parse(value)
        raise Invalid, "Telegram WebApp #{field} must be an object" unless document.is_a?(Hash)

        document
      end

      def secure_compare(left, right)
        return false unless left.bytesize == right.bytesize

        left.bytes.zip(right.bytes).reduce(0) { |result, (a, b)| result | (a ^ b) }.zero?
      end
    end
  end
end
