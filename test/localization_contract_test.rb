# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market_client_bot/bot"
require "zero_x_da/market_client_bot/price_messages"

class LocalizationContractTest < Minitest::Test
  Locale = ZeroXDA::MarketClientBot::Locale
  I18n = ZeroXDA::MarketClientBot::I18n
  CommandMenu = ZeroXDA::MarketClientBot::CommandMenu
  PriceMessages = ZeroXDA::MarketClientBot::PriceMessages

  def test_every_supported_locale_has_complete_interface_copy
    default_interface_keys = I18n::TRANSLATIONS.fetch(Locale::DEFAULT).keys.sort
    default_price_keys = PriceMessages::COPY.fetch(Locale::DEFAULT).keys.sort

    Locale::SUPPORTED.each do |locale|
      assert_equal default_interface_keys, I18n::TRANSLATIONS.fetch(locale).keys.sort, locale
      assert_equal default_price_keys, PriceMessages::COPY.fetch(locale).keys.sort, locale
      assert CommandMenu::COPY.key?(locale), locale
    end
  end

  def test_price_messages_normalize_telegram_language_tags
    assert_equal(
      PriceMessages.choose_product(locale: "fr_FR"),
      PriceMessages.choose_product(locale: "fr-CA")
    )
    assert_equal(
      PriceMessages.choose_product(locale: Locale::DEFAULT),
      PriceMessages.choose_product(locale: "unknown")
    )
  end
end
