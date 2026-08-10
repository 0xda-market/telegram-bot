# frozen_string_literal: true

require_relative "namespace"

require "base64"
require "openssl"
require "time"

module ZeroXDA::Market::TelegramBot
  class TelegramStarsPayments
    PROVIDER = "telegram_stars"
    CURRENCY = "XTR"
    PAYLOAD_VERSION = "v2"
    MAX_PAYLOAD_BYTES = 128
    SIGNATURE_BYTES = 16
    MIN_SECRET_BYTES = 32
    TERMS_VERSION_PATTERN = /\A[A-Za-z0-9_-]{1,24}\z/
    LOCALE_CODES = {
      "en_US" => "en",
      "uk_UA" => "uk",
      "ru_RU" => "ru"
    }.freeze
    LOCALES_BY_CODE = LOCALE_CODES.invert.freeze
    REFUNDABLE_REJECTION_CODES = %w[
      payment_expired
      payment_provider_mismatch
      payment_reference_mismatch
      payment_provider_not_configured
      payment_method_unavailable
      not_found
    ].freeze

    class InvalidPayload < StandardError; end

    def initialize(telegram_api:, market_api:, signing_secret:, payment_terms:, clock: -> { Time.now.utc })
      secret = signing_secret.to_s
      raise ArgumentError, "Telegram payment signing secret must be at least #{MIN_SECRET_BYTES} bytes" if secret.bytesize < MIN_SECRET_BYTES
      raise ArgumentError, "payment_terms is required" unless payment_terms

      @telegram_api = telegram_api
      @market_api = market_api
      @payment_terms = payment_terms
      @signing_secret = secret.b.freeze
      @clock = clock
    end

    def handles?(update)
      update.key?("pre_checkout_query") || update.dig("message", "successful_payment")
    end

    def attach_invoice(order:, telegram_user:, consent:)
      attributes = order.fetch("attributes")
      return order unless attributes.fetch("status") == "payment_pending"

      payment = attributes.fetch("payment")
      provider = payment.fetch("provider", {})
      return order unless provider["provider"] == PROVIDER

      amount = positive_integer(provider.fetch("amount"), "Telegram Stars amount")
      raise InvalidPayload, "Telegram Stars currency mismatch" unless provider.fetch("currency") == CURRENCY

      expires_at = Time.iso8601(payment.fetch("expires_at"))
      raise InvalidPayload, "payment has expired" unless expires_at > current_time
      consent_claims = validated_consent(consent, telegram_user_id: telegram_user.fetch("id"))

      payload = signed_payload(
        order_id: order.fetch("id"),
        telegram_user_id: telegram_user.fetch("id"),
        amount: amount,
        expires_at: expires_at,
        terms_version: consent_claims.fetch(:terms_version),
        consented_at: consent_claims.fetch(:consented_at),
        locale: consent_claims.fetch(:locale)
      )
      product_name = attributes.dig("payload", "product", "name").to_s.strip
      product_name = "0xda-market purchase" if product_name.empty?
      invoice_link = @telegram_api.create_invoice_link(
        title: truncate(product_name, 32),
        description: truncate("Digital product from 0xda-market", 255),
        payload: payload,
        amount: amount
      )

      copy = deep_copy(order)
      copy.fetch("attributes").fetch("payment")["invoice_link"] = invoice_link
      copy.fetch("attributes").fetch("payment")["terms"] = {
        "version" => consent_claims.fetch(:terms_version),
        "accepted_at" => consent_claims.fetch(:consented_at).iso8601(6)
      }
      copy
    end

    def handle(update)
      if (query = update["pre_checkout_query"])
        handle_pre_checkout(query)
      elsif (payment = update.dig("message", "successful_payment"))
        handle_successful_payment(update.fetch("message"), payment)
      end
    end

    private

    def handle_pre_checkout(query)
      begin
        claims = verify_payload(query.fetch("invoice_payload"))
        verify_telegram_user!(claims, query.fetch("from").fetch("id"))
        verify_amount!(claims, query.fetch("total_amount"), query.fetch("currency"))
        raise InvalidPayload, "payment has expired" unless claims.fetch(:expires_at) > current_time
        raise InvalidPayload, "terms consent timestamp is invalid" if claims.fetch(:consented_at) > current_time + 60

        @telegram_api.answer_pre_checkout_query(
          pre_checkout_query_id: query.fetch("id"),
          ok: true
        )
      rescue KeyError, ArgumentError, InvalidPayload
        @telegram_api.answer_pre_checkout_query(
          pre_checkout_query_id: query.fetch("id"),
          ok: false,
          error_message: "This payment can no longer be completed safely. Please reopen 0xda-market and create a new order."
        )
      end
    end

    def handle_successful_payment(message, successful_payment)
      claims = verify_payload(successful_payment.fetch("invoice_payload"))
      telegram_user = message.fetch("from")
      verify_telegram_user!(claims, telegram_user.fetch("id"))
      verify_amount!(claims, successful_payment.fetch("total_amount"), successful_payment.fetch("currency"))
      charge_id = successful_payment.fetch("telegram_payment_charge_id").to_s
      raise InvalidPayload, "Telegram payment charge id is missing" if charge_id.empty?

      user = @market_api.authenticate_telegram(
        user: telegram_user,
        chat: message.fetch("chat")
      )
      @market_api.confirm_marketplace_payment(
        actor_user_id: user.fetch("id"),
        order_id: claims.fetch(:order_id),
        reference: charge_id,
        provider: PROVIDER,
        amount: claims.fetch(:amount),
        currency: CURRENCY,
        data: {
          telegram_payment_charge_id: charge_id,
          provider_payment_charge_id: successful_payment["provider_payment_charge_id"],
          invoice_payload: successful_payment.fetch("invoice_payload"),
          terms_version: claims.fetch(:terms_version),
          terms_sha256: @payment_terms.digest(locale: claims.fetch(:locale)),
          terms_accepted_at: claims.fetch(:consented_at).iso8601(6),
          terms_locale: claims.fetch(:locale)
        }.compact
      )
    rescue MarketAPI::Error => error
      handle_confirmation_failure(
        error,
        message: message,
        successful_payment: successful_payment
      )
    rescue KeyError, ArgumentError, InvalidPayload => error
      refund_unverifiable_payment(
        message: message,
        successful_payment: successful_payment,
        reason: error.class.name
      )
    end

    def handle_confirmation_failure(error, message:, successful_payment:)
      charge_id = successful_payment["telegram_payment_charge_id"].to_s
      if REFUNDABLE_REJECTION_CODES.include?(error.code) && !charge_id.empty?
        @telegram_api.refund_star_payment(
          user_id: message.fetch("from").fetch("id"),
          telegram_payment_charge_id: charge_id
        )
        warn "refunded rejected Telegram Stars payment #{charge_id}: #{error.code}"
        return nil
      end

      # A timeout or 5xx may have happened after core committed the payment.
      # Returning an error lets Telegram retry the same authoritative update;
      # idempotency is enforced by the signed payload and charge reference.
      raise error
    end

    def refund_unverifiable_payment(message:, successful_payment:, reason:)
      charge_id = successful_payment["telegram_payment_charge_id"].to_s
      currency = successful_payment["currency"].to_s
      raise InvalidPayload, "unverifiable payment has no refundable Stars charge" if charge_id.empty? || currency != CURRENCY

      @telegram_api.refund_star_payment(
        user_id: message.fetch("from").fetch("id"),
        telegram_payment_charge_id: charge_id
      )
      warn "refunded unverifiable Telegram Stars payment #{charge_id}: #{reason}"
      nil
    end

    def signed_payload(order_id:, telegram_user_id:, amount:, expires_at:, terms_version:, consented_at:, locale:)
      order = resource_id(order_id)
      user = telegram_user_id.to_s
      raise InvalidPayload, "Telegram user id is invalid" unless user.match?(/\A\d+\z/)
      raise InvalidPayload, "terms version is invalid" unless terms_version.to_s.match?(TERMS_VERSION_PATTERN)
      locale_code = LOCALE_CODES.fetch(locale.to_s, "en")

      body = [
        PAYLOAD_VERSION,
        order,
        user,
        amount.to_s,
        expires_at.to_i.to_s,
        terms_version.to_s,
        consented_at.to_i.to_s,
        locale_code
      ].join(".")
      payload = "#{body}.#{signature(body)}"
      raise InvalidPayload, "Telegram invoice payload is too large" if payload.bytesize > MAX_PAYLOAD_BYTES

      payload
    end

    def verify_payload(payload)
      value = payload.to_s
      raise InvalidPayload, "Telegram invoice payload is invalid" if value.empty? || value.bytesize > MAX_PAYLOAD_BYTES

      version, order_id, user_id, amount, expires_at, terms_version, consented_at, locale_code, supplied_signature = value.split(".", 9)
      raise InvalidPayload, "Telegram invoice payload is invalid" unless supplied_signature && version == PAYLOAD_VERSION
      raise InvalidPayload, "terms version is invalid" unless terms_version.to_s.match?(TERMS_VERSION_PATTERN)
      locale = LOCALES_BY_CODE[locale_code]
      raise InvalidPayload, "terms locale is invalid" unless locale

      body = [version, order_id, user_id, amount, expires_at, terms_version, consented_at, locale_code].join(".")
      expected_signature = signature(body)
      raise InvalidPayload, "Telegram invoice payload signature is invalid" unless secure_compare(expected_signature, supplied_signature)

      raise InvalidPayload, "Telegram user id is invalid" unless user_id.match?(/\A\d+\z/)
      {
        order_id: resource_id(order_id),
        telegram_user_id: user_id,
        amount: positive_integer(amount, "Telegram Stars amount"),
        expires_at: Time.at(Integer(expires_at), in: "+00:00"),
        terms_version: terms_version,
        consented_at: Time.at(Integer(consented_at), in: "+00:00"),
        locale: locale
      }
    rescue ArgumentError, TypeError
      raise InvalidPayload, "Telegram invoice payload is invalid"
    end

    def validated_consent(consent, telegram_user_id:)
      unless consent.is_a?(Hash) && consent["accepted"] == true
        raise InvalidPayload, "purchase terms must be accepted before invoice creation"
      end
      version = consent["terms_version"].to_s
      raise InvalidPayload, "terms version is invalid" unless version == @payment_terms.version && version.match?(TERMS_VERSION_PATTERN)
      raise InvalidPayload, "terms consent belongs to another user" unless consent["telegram_user_id"].to_s == telegram_user_id.to_s
      locale = consent["locale"].to_s
      locale = "en_US" unless LOCALE_CODES.key?(locale)
      accepted_at = Time.iso8601(consent.fetch("accepted_at"))
      raise InvalidPayload, "terms consent timestamp is invalid" if accepted_at > current_time + 60

      { terms_version: version, consented_at: accepted_at, locale: locale }
    rescue KeyError, ArgumentError
      raise InvalidPayload, "purchase terms consent is invalid"
    end

    def verify_telegram_user!(claims, user_id)
      return if claims.fetch(:telegram_user_id) == user_id.to_s

      raise InvalidPayload, "Telegram payment belongs to another user"
    end

    def verify_amount!(claims, amount, currency)
      received = positive_integer(amount, "Telegram Stars amount")
      return if currency.to_s == CURRENCY && received == claims.fetch(:amount)

      raise InvalidPayload, "Telegram payment amount does not match the invoice"
    end

    def signature(body)
      digest = OpenSSL::HMAC.digest("SHA256", @signing_secret, body)[0, SIGNATURE_BYTES]
      Base64.urlsafe_encode64(digest, padding: false)
    end

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize

      left.bytes.zip(right.bytes).reduce(0) { |result, (a, b)| result | (a ^ b) }.zero?
    end

    def resource_id(value)
      id = value.to_s
      raise InvalidPayload, "order id is invalid" unless id.match?(/\A[A-Za-z0-9:_-]{1,80}\z/)

      id
    end

    def positive_integer(value, field)
      number = Integer(value)
      raise InvalidPayload, "#{field} must be positive" unless number.positive?

      number
    rescue ArgumentError, TypeError
      raise InvalidPayload, "#{field} must be a positive integer"
    end

    def truncate(value, maximum)
      value.to_s.each_char.take(maximum).join
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    end

    def current_time
      value = @clock.call
      value.is_a?(Time) ? value.utc : Time.parse(value.to_s).utc
    end
  end
end
