# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/bot"
require "zero_x_da/market/telegram_bot/price_messages"

class LocalizationContractTest < Minitest::Test
  Locale = ZeroXDA::Market::TelegramBot::Locale
  I18n = ZeroXDA::Market::TelegramBot::I18n
  CommandMenu = ZeroXDA::Market::TelegramBot::CommandMenu
  PriceMessages = ZeroXDA::Market::TelegramBot::PriceMessages

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
