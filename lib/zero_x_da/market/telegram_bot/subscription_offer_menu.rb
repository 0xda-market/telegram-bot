# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "namespace"
require_relative "locale"

module ZeroXDA::Market::TelegramBot
  # Read-only subscription offer view. Prices are informational until the
  # issuer's entitlement grant and both settlement paths are available.
  class SubscriptionOfferMenu
    Screen = Struct.new(:text, :reply_markup, keyword_init: true)

    COPY = {
      "en_US" => { buy_for: "Buy for:", back: "‹ Back", home: "⌂ Home", balance: "Balance",
                   unavailable: "Unavailable", preview: "Preview only · purchasing is not available yet." },
      "uk_UA" => { buy_for: "Купити за:", back: "‹ Назад", home: "⌂ Головна", balance: "Баланс",
                   unavailable: "Недоступно", preview: "Попередній перегляд · купівля поки недоступна." },
      "ru_RU" => { buy_for: "Купить за:", back: "‹ Назад", home: "⌂ Главная", balance: "Баланс",
                   unavailable: "Недоступно", preview: "Предпросмотр · покупка пока недоступна." },
      "fr_FR" => { buy_for: "Acheter pour :", back: "‹ Retour", home: "⌂ Accueil", balance: "Solde",
                   unavailable: "Indisponible", preview: "Aperçu · achat indisponible pour le moment." },
      "es_ES" => { buy_for: "Comprar por:", back: "‹ Volver", home: "⌂ Inicio", balance: "Saldo",
                   unavailable: "No disponible", preview: "Vista previa · compra todavía no disponible." },
      "de_DE" => { buy_for: "Kaufen für:", back: "‹ Zurück", home: "⌂ Start", balance: "Guthaben",
                   unavailable: "Nicht verfügbar", preview: "Vorschau · Kauf derzeit nicht möglich." }
    }.freeze

    def build(product:, locale: Locale::DEFAULT, seed_balance: nil)
      metadata = product.dig("attributes", "metadata") || {}
      raise ArgumentError, "not a 0x1 subscription" unless metadata["family"] == "0x1_subscription"

      sku = product.fetch("id")
      copy = COPY.fetch(Locale.normalize(locale))
      seed_price = metadata["seed_price"]
      amount = seed_price.is_a?(Hash) && seed_price["currency"] == "seeds" ? seed_price["amount"] : nil
      seeds = valid_seed_amount(amount) ? "#{amount} ₴€£" : "— ₴€£"
      localized_price = product.dig("attributes", "preview_price")
      money = formatted_money(localized_price)
      balance = valid_balance(seed_balance) ? seed_balance.to_s : "—"

      rows = [
        [
          { text: "·", callback_data: "n" },
          { text: copy.fetch(:buy_for), callback_data: "n" },
          { text: "·", callback_data: "n" }
        ],
        [
          { text: seeds, callback_data: "x:#{sku}" },
          { text: money, callback_data: "y:#{sku}" }
        ],
        [
          { text: copy.fetch(:back), callback_data: "c:b:#{sku}" },
          { text: copy.fetch(:home), callback_data: "h:b" },
          { text: "#{copy.fetch(:balance)}: #{balance} ₴€£", callback_data: "z:#{sku}" }
        ]
      ]
      Screen.new(
        text: "#{product.dig("attributes", "name")}\n\n#{copy.fetch(:preview)}",
        reply_markup: { inline_keyboard: rows }
      )
    end

    private

    def formatted_money(price)
      return "— USDT" unless price.is_a?(Hash)

      currency = price["currency"].to_s
      amount = price["amount"].to_s
      return "— USDT" unless currency.match?(/\A[A-Z]{3,8}\z/) && amount.match?(/\A\d+(?:\.\d+)?\z/)

      "#{amount} #{currency}"
    end

    def valid_seed_amount(amount)
      amount.is_a?(Integer) && amount.positive?
    end

    def valid_balance(balance)
      balance.is_a?(Integer) && balance >= 0
    end
  end
end
