# frozen_string_literal: true

require_relative "locale"

module ZeroXDA
  module MarketClientBot
    # Bot-owned interface copy. Product names and ordering are deliberately
    # absent: those arrive from the localized database catalog via the API.
    module PriceMessages
      COPY = {
        "en_US" => {
          title: "📦 Price application",
          base_currency: "base currency: USDT",
          previous: "yesterday",
          current: "current",
          edited_by: "edited by",
          applied_at: "applied at",
          update: "Update a price: /apply_price <sku|position|short name> <amount in USDT>",
          review: "Review all prices again: /apply_prices",
          persistence: "Until a new application is submitted, the last applied prices remain in effect.",
          usage: "format: /apply_price <sku|position|short name> <amount in USDT>\n" \
                 "example: /apply_price Premium 6m 7.45",
          choose_product: "choose a product to update:",
          enter_amount: "enter the new price for %s in USDT, e.g. 7.45",
          invalid_amount: "invalid amount. enter a number, e.g. 7.45",
          product_not_found: "product not found: %s\n" \
                             "enter a sku, position or short name, or pick a product button"
        },
        "uk_UA" => {
          title: "📦 Застосування цін",
          base_currency: "базова валюта: USDT",
          previous: "вчора",
          current: "поточна",
          edited_by: "редактор",
          applied_at: "застосовано",
          update: "Оновити ціну: /apply_price <sku|позиція|коротка назва> <сума в USDT>",
          review: "Переглянути всі ціни: /apply_prices",
          persistence: "До наступного застосування діють останні встановлені ціни.",
          usage: "формат: /apply_price <sku|позиція|коротка назва> <сума в USDT>\n" \
                 "приклад: /apply_price Premium 6m 7.45",
          choose_product: "обери продукт для оновлення ціни:",
          enter_amount: "введи нову ціну для %s у USDT, наприклад 7.45",
          invalid_amount: "некоректна сума. введи число, наприклад 7.45",
          product_not_found: "продукт не знайдено: %s\n" \
                             "введи sku, позицію або коротку назву, або обери продукт кнопкою"
        },
        "ru_RU" => {
          title: "📦 Применение цен",
          base_currency: "базовая валюта: USDT",
          previous: "вчера",
          current: "текущая",
          edited_by: "редактор",
          applied_at: "применено",
          update: "Обновить цену: /apply_price <sku|позиция|короткое название> <сумма в USDT>",
          review: "Просмотреть все цены: /apply_prices",
          persistence: "До следующего применения действуют последние установленные цены.",
          usage: "формат: /apply_price <sku|позиция|короткое название> <сумма в USDT>\n" \
                 "пример: /apply_price Premium 6m 7.45",
          choose_product: "выберите продукт для обновления цены:",
          enter_amount: "введите новую цену для %s в USDT, например 7.45",
          invalid_amount: "некорректная сумма. введите число, например 7.45",
          product_not_found: "продукт не найден: %s\n" \
                             "введите sku, позицию или короткое название либо выберите продукт кнопкой"
        },
        "fr_FR" => {
          title: "📦 Application des prix",
          base_currency: "devise de base : USDT",
          previous: "hier",
          current: "actuel",
          edited_by: "modifié par",
          applied_at: "appliqué le",
          update: "Mettre à jour un prix : /apply_price <sku|position|nom court> <montant en USDT>",
          review: "Revoir tous les prix : /apply_prices",
          persistence: "Les derniers prix appliqués restent actifs jusqu’à la prochaine application.",
          usage: "format : /apply_price <sku|position|nom court> <montant en USDT>\n" \
                 "exemple : /apply_price Premium 6m 7.45",
          choose_product: "choisissez un produit dont le prix doit être mis à jour :",
          enter_amount: "saisissez le nouveau prix de %s en USDT, par exemple 7.45",
          invalid_amount: "montant incorrect. saisissez un nombre, par exemple 7.45",
          product_not_found: "produit introuvable : %s\n" \
                             "saisissez un sku, une position ou un nom court, ou choisissez un bouton"
        },
        "es_ES" => {
          title: "📦 Aplicación de precios",
          base_currency: "moneda base: USDT",
          previous: "ayer",
          current: "actual",
          edited_by: "editado por",
          applied_at: "aplicado el",
          update: "Actualizar un precio: /apply_price <sku|posición|nombre corto> <importe en USDT>",
          review: "Revisar todos los precios: /apply_prices",
          persistence: "Los últimos precios aplicados siguen activos hasta la siguiente aplicación.",
          usage: "formato: /apply_price <sku|posición|nombre corto> <importe en USDT>\n" \
                 "ejemplo: /apply_price Premium 6m 7.45",
          choose_product: "elige un producto para actualizar su precio:",
          enter_amount: "introduce el nuevo precio de %s en USDT, por ejemplo 7.45",
          invalid_amount: "importe incorrecto. introduce un número, por ejemplo 7.45",
          product_not_found: "producto no encontrado: %s\n" \
                             "introduce un sku, posición o nombre corto, o elige un botón"
        },
        "de_DE" => {
          title: "📦 Preisübernahme",
          base_currency: "Basiswährung: USDT",
          previous: "gestern",
          current: "aktuell",
          edited_by: "bearbeitet von",
          applied_at: "übernommen am",
          update: "Preis aktualisieren: /apply_price <sku|position|kurzname> <Betrag in USDT>",
          review: "Alle Preise erneut prüfen: /apply_prices",
          persistence: "Bis zur nächsten Übernahme bleiben die zuletzt gesetzten Preise aktiv.",
          usage: "Format: /apply_price <sku|position|kurzname> <Betrag in USDT>\n" \
                 "Beispiel: /apply_price Premium 6m 7.45",
          choose_product: "Wähle ein Produkt zur Preisaktualisierung:",
          enter_amount: "Gib den neuen Preis für %s in USDT ein, z. B. 7.45",
          invalid_amount: "Ungültiger Betrag. Gib eine Zahl ein, z. B. 7.45",
          product_not_found: "Produkt nicht gefunden: %s\n" \
                             "Gib sku, Position oder Kurzname ein oder wähle eine Produktschaltfläche"
        }
      }.freeze

      module_function

      def application_text(proposal, locale: Locale::DEFAULT)
        copy = copy_for(locale)
        lines = [copy.fetch(:title), copy.fetch(:base_currency), ""]
        proposal.each do |entry|
          attributes = entry.fetch("attributes")
          lines << "#{attributes.fetch("position")}. #{attributes.fetch("name")} (#{entry.fetch("id")})"

          amounts = labeled_parts(copy,
                                  previous: attributes["previous_amount_usdt"],
                                  current: attributes["current_amount_usdt"])
          lines << "   #{amounts}" unless amounts.empty?

          details = labeled_parts(copy,
                                  edited_by: attributes["current_edited_by_user_id"],
                                  applied_at: attributes["current_applied_at"])
          lines << "   #{details}" unless details.empty?
        end
        lines << ""
        lines << copy.fetch(:update)
        lines << copy.fetch(:review)
        lines << copy.fetch(:persistence)
        lines.join("\n")
      end

      def apply_price_usage(locale: Locale::DEFAULT)
        copy_for(locale).fetch(:usage)
      end

      def choose_product(locale: Locale::DEFAULT)
        copy_for(locale).fetch(:choose_product)
      end

      def enter_amount(name, locale: Locale::DEFAULT)
        format(copy_for(locale).fetch(:enter_amount), name)
      end

      def invalid_amount(locale: Locale::DEFAULT)
        copy_for(locale).fetch(:invalid_amount)
      end

      def product_not_found(reference, locale: Locale::DEFAULT)
        format(copy_for(locale).fetch(:product_not_found), reference)
      end

      # Renders only labels whose values are present; skips empty ones entirely.
      def labeled_parts(copy, pairs)
        pairs.filter_map do |label_key, value|
          next if value.nil? || value.to_s.empty?

          "#{copy.fetch(label_key)}: #{value}"
        end.join(" · ")
      end

      def copy_for(locale)
        COPY.fetch(Locale.normalize(locale), COPY.fetch(Locale::DEFAULT))
      end
    end
  end
end
