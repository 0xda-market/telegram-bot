# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require "json"
require "openssl"

module ZeroXDA::Market::TelegramBot
  # A restart-safe confirmation bound to the displayed price, Bond, Telegram
  # sender and message. Its timestamp also identifies retries of the same order.
  module SpecialConfirmation
    TTL = 15 * 60
    PATTERN = /\A(0x1_special_(?:1|3|6|12)m):([a-z0-9]+):([a-z0-9]+):([a-z0-9]+):([A-Za-z0-9_-]{16})\z/

    module_function

    def issue(secret:, callback:, sku:, bond:, price_id:, amount:, now:)
      payload = [sku, (now.to_r * 1000).to_i.to_s(36), price_id.to_s(36), amount.to_s(36)].join(":")
      token = "#{payload}:#{signature(secret, callback, bond, payload)}"
      raise ArgumentError, "Special confirmation exceeds Telegram callback limit" if token.bytesize > 61

      token
    end

    def verify(token:, secret:, callback:, bond:, now:)
      match = PATTERN.match(token)
      return unless match

      sku, nonce, price, amount, mac = match.captures
      issued_at = nonce.to_i(36) / 1000.0
      return unless (now.to_f - issued_at).between?(0, TTL)
      return unless price.to_i(36).positive? && amount.to_i(36).positive?

      expected = signature(secret, callback, bond, [sku, nonce, price, amount].join(":"))
      return unless OpenSSL.fixed_length_secure_compare(expected, mac)

      { sku: sku, nonce: nonce, price_id: price.to_i(36), amount: amount.to_i(36) }
    end

    def signature(secret, callback, bond, payload)
      context = ["market-special-confirm-v1", callback.fetch("from").fetch("id"),
                 callback.dig("message", "chat", "id"), callback.dig("message", "message_id"), bond, payload]
      [OpenSSL::HMAC.digest("SHA256", secret, context.to_json).byteslice(0, 12)].pack("m0").tr("+/", "-_")
    end
  end
end
