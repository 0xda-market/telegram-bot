# frozen_string_literal: true

require_relative "locale"

module ZeroXDA
  module TelegramBot
    class CatalogMenu
      PAGE_SIZE = 6
      COLUMNS = 3
      FAMILY_LABELS = {
        "en_US" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Crypto assets",
          "currency" => "Currencies"
        },
        "uk_UA" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Криптоактиви",
          "currency" => "Валюти"
        },
        "ru_RU" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Криптоактивы",
          "currency" => "Валюты"
        },
        "fr_FR" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Cryptoactifs",
          "currency" => "Devises"
        },
        "es_ES" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Criptoactivos",
          "currency" => "Monedas"
        },
        "de_DE" => {
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Krypto-Assets",
          "currency" => "Währungen"
        }
      }.freeze
      NAVIGATION = {
        "en_US" => { previous: "‹ Previous", home: "⌂ Categories", next: "Next ›" },
        "uk_UA" => { previous: "‹ Назад", home: "⌂ Категорії", next: "Далі ›" },
        "ru_RU" => { previous: "‹ Назад", home: "⌂ Категории", next: "Далее ›" },
        "fr_FR" => { previous: "‹ Précédent", home: "⌂ Catégories", next: "Suivant ›" },
        "es_ES" => { previous: "‹ Anterior", home: "⌂ Categorías", next: "Siguiente ›" },
        "de_DE" => { previous: "‹ Zurück", home: "⌂ Kategorien", next: "Weiter ›" }
      }.freeze

      Screen = Struct.new(:title, :reply_markup, keyword_init: true)

      def root(products:, mode:, locale: Locale::DEFAULT)
        groups = grouped(products)
        buttons = groups.map do |family, entries|
          {
            text: family_label(family, locale),
            callback_data: "c:#{mode}:#{entries.first.fetch("id")}"
          }
        end
        Screen.new(title: nil, reply_markup: { inline_keyboard: buttons.map { |button| [button] } })
      end

      def category(products:, mode:, anchor_sku:, locale: Locale::DEFAULT)
        groups = grouped(products)
        family, entries = groups.find do |_group, items|
          items.any? { |product| product.fetch("id") == anchor_sku }
        end
        raise ArgumentError, "catalog category is unavailable" unless family

        anchor_index = entries.index { |product| product.fetch("id") == anchor_sku }
        page_start = (anchor_index / PAGE_SIZE) * PAGE_SIZE
        page = entries.slice(page_start, PAGE_SIZE) || []
        rows = page.map do |product|
          {
            text: product.dig("attributes", "button_label") || product.dig("attributes", "name"),
            callback_data: "#{mode}:#{product.fetch("id")}"
          }
        end.each_slice(COLUMNS).to_a
        rows << navigation_row(
          mode: mode,
          entries: entries,
          page_start: page_start,
          locale: locale
        )
        Screen.new(title: family_label(family, locale), reply_markup: { inline_keyboard: rows })
      end

      private

      def grouped(products)
        products.sort_by { |product| product.dig("attributes", "position").to_i }
                .group_by { |product| family_for(product) }
                .sort_by { |_family, entries| entries.first.dig("attributes", "position").to_i }
      end

      def family_for(product)
        product.dig("attributes", "metadata", "family").to_s.then do |value|
          value.empty? ? "other" : value
        end
      end

      def family_label(family, locale)
        copy = FAMILY_LABELS.fetch(Locale.normalize(locale), FAMILY_LABELS.fetch(Locale::DEFAULT))
        copy[family] || family.tr("_-", " ").split.map(&:capitalize).join(" ")
      end

      def navigation_row(mode:, entries:, page_start:, locale:)
        copy = NAVIGATION.fetch(Locale.normalize(locale), NAVIGATION.fetch(Locale::DEFAULT))
        previous = if page_start.positive?
                     anchor = entries.fetch([page_start - PAGE_SIZE, 0].max).fetch("id")
                     { text: copy.fetch(:previous), callback_data: "c:#{mode}:#{anchor}" }
                   else
                     { text: "·", callback_data: "n" }
                   end
        home = { text: copy.fetch(:home), callback_data: "h:#{mode}" }
        following = page_start + PAGE_SIZE
        next_button = if following < entries.length
                        { text: copy.fetch(:next), callback_data: "c:#{mode}:#{entries.fetch(following).fetch("id")}" }
                      else
                        { text: "·", callback_data: "n" }
                      end
        [previous, home, next_button]
      end
    end
  end
end
