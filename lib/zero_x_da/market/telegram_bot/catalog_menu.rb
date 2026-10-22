# frozen_string_literal: true

require_relative "namespace"

require_relative "locale"

module ZeroXDA::Market::TelegramBot
    class CatalogMenu
      PAGE_SIZE = 6
      SUBSCRIPTION_PAGE_SIZE = 8
      COLUMNS = 3
      SUBSCRIPTION_FAMILY = "0x1_subscription"
      SUBSCRIPTION_TIERS = %w[exclusive special].freeze
      SUBSCRIPTION_DURATIONS = [1, 3, 6, 12].freeze
      SUBSCRIPTION_LABELS = {
        "en_US" => ["month", "mo."],
        "uk_UA" => ["місяць", "міс."],
        "ru_RU" => ["месяц", "мес."],
        "fr_FR" => ["mois", "mois"],
        "es_ES" => ["mes", "meses"],
        "de_DE" => ["Monat", "Mon."]
      }.freeze
      SUBSCRIPTION_HEADINGS = {
        "en_US" => "Choose a 0x1 subscription:",
        "uk_UA" => "Обери підписку 0x1:",
        "ru_RU" => "Выбери подписку 0x1:",
        "fr_FR" => "Choisissez un abonnement 0x1 :",
        "es_ES" => "Elige una suscripción 0x1:",
        "de_DE" => "Wähle ein 0x1-Abo:"
      }.freeze
      FAMILY_LABELS = {
        "en_US" => {
          "0x1_subscription" => "0x1 Subscriptions",
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Crypto assets",
          "currency" => "Currencies"
        },
        "uk_UA" => {
          "0x1_subscription" => "Підписки 0x1",
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Криптоактиви",
          "currency" => "Валюти"
        },
        "ru_RU" => {
          "0x1_subscription" => "Подписки 0x1",
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Криптоактивы",
          "currency" => "Валюты"
        },
        "fr_FR" => {
          "0x1_subscription" => "Abonnements 0x1",
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Cryptoactifs",
          "currency" => "Devises"
        },
        "es_ES" => {
          "0x1_subscription" => "Suscripciones 0x1",
          "telegram_premium" => "Telegram Premium",
          "telegram_stars" => "Telegram Stars",
          "crypto_asset" => "Criptoactivos",
          "currency" => "Monedas"
        },
        "de_DE" => {
          "0x1_subscription" => "0x1-Abonnements",
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

      Screen = Struct.new(:title, :reply_markup, :family, :has_previews, keyword_init: true)

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

        page_size = family == SUBSCRIPTION_FAMILY ? SUBSCRIPTION_PAGE_SIZE : PAGE_SIZE
        anchor_index = entries.index { |product| product.fetch("id") == anchor_sku }
        page_start = (anchor_index / page_size) * page_size
        page = entries.slice(page_start, page_size) || []
        rows = (family == SUBSCRIPTION_FAMILY && page_start.zero? && subscription_rows(page, mode, locale)) ||
               page.map { |product| button_for(product, mode, locale) }.each_slice(COLUMNS).to_a
        rows << navigation_row(
          mode: mode,
          entries: entries,
          page_start: page_start,
          page_size: page_size,
          locale: locale
        )
        title = if family == SUBSCRIPTION_FAMILY
                  SUBSCRIPTION_HEADINGS.fetch(Locale.normalize(locale), SUBSCRIPTION_HEADINGS.fetch(Locale::DEFAULT))
                else
                  family_label(family, locale)
                end
        Screen.new(
          title: title, family: family, has_previews: page.any? { |product| product.dig("attributes", "preview") },
          reply_markup: { inline_keyboard: rows }
        )
      end

      private

      def grouped(products)
        products.sort_by { |product| product.dig("attributes", "position").to_i }
                .group_by { |product| family_for(product) }
                .map do |family, entries|
                  sorted = family == SUBSCRIPTION_FAMILY ? entries.sort_by { |entry| subscription_order(entry) } : entries
                  [family, sorted]
                end
                .sort_by { |_family, entries| entries.map { |entry| entry.dig("attributes", "position").to_i }.min }
      end

      def subscription_order(product)
        metadata = product.dig("attributes", "metadata") || {}
        [
          SUBSCRIPTION_TIERS.index(metadata["tier"]) || SUBSCRIPTION_TIERS.length,
          SUBSCRIPTION_DURATIONS.index(metadata["duration_months"].to_i) || SUBSCRIPTION_DURATIONS.length,
          product.dig("attributes", "position").to_i
        ]
      end

      def subscription_rows(page, mode, locale)
        return unless page.length == SUBSCRIPTION_PAGE_SIZE

        by_tier_duration = page.to_h do |product|
          metadata = product.dig("attributes", "metadata") || {}
          [[metadata["tier"], metadata["duration_months"].to_i], product]
        end
        expected = SUBSCRIPTION_TIERS.product(SUBSCRIPTION_DURATIONS)
        return unless by_tier_duration.keys.sort == expected.sort

        blank = -> { { text: "·", callback_data: "n" } }
        [
          [blank.call, button_for(by_tier_duration.fetch(["exclusive", 1]), mode, locale), blank.call],
          [3, 6, 12].map { |months| button_for(by_tier_duration.fetch(["exclusive", months]), mode, locale) },
          [blank.call, button_for(by_tier_duration.fetch(["special", 1]), mode, locale), blank.call],
          [3, 6, 12].map { |months| button_for(by_tier_duration.fetch(["special", months]), mode, locale) }
        ]
      end

      def button_for(product, mode, locale)
        metadata = product.dig("attributes", "metadata") || {}
        label = product.dig("attributes", "button_label") || product.dig("attributes", "name")
        if family_for(product) == SUBSCRIPTION_FAMILY &&
           SUBSCRIPTION_TIERS.include?(metadata["tier"]) &&
           SUBSCRIPTION_DURATIONS.include?(metadata["duration_months"].to_i)
          duration = metadata["duration_months"].to_i
          forms = SUBSCRIPTION_LABELS.fetch(Locale.normalize(locale), SUBSCRIPTION_LABELS.fetch(Locale::DEFAULT))
          suffix = duration == 1 ? forms.first : forms.last
          label = "#{metadata.fetch("tier").capitalize} #{duration} #{suffix}"
        end
        callback_mode = product.dig("attributes", "preview") ? "v" : mode
        { text: label, callback_data: "#{callback_mode}:#{product.fetch("id")}" }
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

      def navigation_row(mode:, entries:, page_start:, page_size:, locale:)
        copy = NAVIGATION.fetch(Locale.normalize(locale), NAVIGATION.fetch(Locale::DEFAULT))
        previous = if page_start.positive?
                     anchor = entries.fetch([page_start - page_size, 0].max).fetch("id")
                     { text: copy.fetch(:previous), callback_data: "c:#{mode}:#{anchor}" }
                   else
                     { text: "·", callback_data: "n" }
                   end
        home = { text: copy.fetch(:home), callback_data: "h:#{mode}" }
        following = page_start + page_size
        next_button = if following < entries.length
                        { text: copy.fetch(:next), callback_data: "c:#{mode}:#{entries.fetch(following).fetch("id")}" }
                      else
                        { text: "·", callback_data: "n" }
                      end
        [previous, home, next_button]
      end
    end
end
