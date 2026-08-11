# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/payment_terms"

class PaymentTermsTest < Minitest::Test
  def setup
    @now = Time.utc(2026, 8, 11, 0, 0, 0)
    @terms = ZeroXDA::Market::TelegramBot::PaymentTerms.new(
      public_url: "https://market.example",
      clock: -> { @now }
    )
  end

  def test_metadata_exposes_version_digest_and_public_https_url
    metadata = @terms.metadata(locale: "uk_UA")

    assert_equal ZeroXDA::Market::TelegramBot::PaymentTerms::VERSION, metadata.fetch("version")
    assert_equal @terms.digest(locale: "uk_UA"), metadata.fetch("sha256")
    assert_equal "https://market.example/webapp/terms?locale=uk_UA", metadata.fetch("url")
    refute_empty metadata.fetch("prompt")
    refute_empty metadata.fetch("agree_label")
  end

  def test_consent_must_be_explicit_and_match_current_version
    assert_raises(ArgumentError) do
      @terms.accept(client_consent: nil, telegram_user_id: 77, locale: "en_US")
    end

    assert_raises(ArgumentError) do
      @terms.accept(
        client_consent: { "accepted" => true, "version" => "old" },
        telegram_user_id: 77,
        locale: "en_US"
      )
    end

    proof = @terms.accept(
      client_consent: {
        "accepted" => true,
        "version" => ZeroXDA::Market::TelegramBot::PaymentTerms::VERSION
      },
      telegram_user_id: 77,
      locale: "en_US"
    )

    assert_equal true, proof.fetch("accepted")
    assert_equal "77", proof.fetch("telegram_user_id")
    assert_equal "en_US", proof.fetch("locale")
    assert_equal @now.iso8601(6), proof.fetch("accepted_at")
    assert_equal @terms.digest(locale: "en_US"), proof.fetch("terms_sha256")
  end

  def test_terms_are_available_in_supported_checkout_locales_and_name_support_route
    %w[en_US uk_UA ru_RU].each do |locale|
      text = @terms.text(locale: locale)
      assert_includes text, "/paysupport"
      assert_includes text, "0xda-market"
      assert_includes @terms.html(locale: locale), @terms.metadata(locale: locale).fetch("title")
    end
  end

  def test_any_terms_content_change_requires_an_explicit_version_constant
    assert_match(/\A\d{8}v\d+\z/, ZeroXDA::Market::TelegramBot::PaymentTerms::VERSION)
    assert_equal 64, @terms.digest(locale: "en_US").length
  end
end
