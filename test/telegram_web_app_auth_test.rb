# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "openssl"
require "uri"
require "zero_x_da/market_client_bot/telegram_web_app_auth"

class TelegramWebAppAuthTest < Minitest::Test
  TOKEN = "123456:telegram-test-token"
  NOW = Time.utc(2026, 7, 31, 17, 0, 0)

  def setup
    @auth = ZeroXDA::MarketClientBot::TelegramWebAppAuth.new(
      bot_token: TOKEN,
      max_age_seconds: 3600,
      clock: -> { NOW }
    )
  end

  def test_validates_signed_init_data_and_returns_a_private_chat_fallback
    session = @auth.verify(signed_init_data)

    assert_equal 99, session.user.fetch("id")
    assert_equal "sasha", session.user.fetch("username")
    assert_equal 99, session.chat.fetch("id")
    assert_equal "private", session.chat.fetch("type")
    assert_equal NOW.to_i - 30, session.auth_date.to_i
  end

  def test_rejects_tampered_user_data
    tampered = signed_init_data.sub("sasha", "attacker")

    error = assert_raises(ZeroXDA::MarketClientBot::TelegramWebAppAuth::Invalid) do
      @auth.verify(tampered)
    end

    assert_includes error.message, "signature is invalid"
  end

  def test_rejects_expired_init_data
    expired = signed_init_data(auth_date: NOW.to_i - 3601)

    error = assert_raises(ZeroXDA::MarketClientBot::TelegramWebAppAuth::Invalid) do
      @auth.verify(expired)
    end

    assert_includes error.message, "expired"
  end

  def test_rejects_duplicate_fields
    duplicated = "#{signed_init_data}&auth_date=#{NOW.to_i}"

    error = assert_raises(ZeroXDA::MarketClientBot::TelegramWebAppAuth::Invalid) do
      @auth.verify(duplicated)
    end

    assert_includes error.message, "duplicated"
  end

  private

  def signed_init_data(auth_date: NOW.to_i - 30)
    fields = {
      "auth_date" => auth_date.to_s,
      "query_id" => "AAH-test-query",
      "user" => JSON.generate(
        "id" => 99,
        "username" => "sasha",
        "first_name" => "Sasha",
        "language_code" => "uk"
      )
    }
    data_check_string = fields.sort.map { |key, value| "#{key}=#{value}" }.join("\n")
    secret_key = OpenSSL::HMAC.digest("SHA256", "WebAppData", TOKEN)
    fields["hash"] = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)
    URI.encode_www_form(fields)
  end
end
