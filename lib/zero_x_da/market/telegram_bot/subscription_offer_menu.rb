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

    # Authorization is a deliberately non-operational entry point until
    # aiaiaiai ecosystem × 0x1 account binding is implemented.
    AUTH_COPY = {
      "en_US" => { sign_in: "Sign in to 0x1", pending: "Authorization is not available yet.", offline: "Balance unavailable" },
      "uk_UA" => { sign_in: "Авторизуватися у 0x1", pending: "Авторизація поки недоступна.", offline: "Баланс недоступний" },
      "ru_RU" => { sign_in: "Авторизоваться в 0x1", pending: "Авторизация пока недоступна.", offline: "Баланс недоступен" },
      "fr_FR" => { sign_in: "Se connecter à 0x1", pending: "L'autorisation est indisponible pour le moment.", offline: "Solde indisponible" },
      "es_ES" => { sign_in: "Iniciar sesión en 0x1", pending: "La autorización aún no está disponible.", offline: "Saldo no disponible" },
      "de_DE" => { sign_in: "Bei 0x1 anmelden", pending: "Die Anmeldung ist noch nicht verfügbar.", offline: "Guthaben nicht verfügbar" }
    }.freeze

    def authorization(sku:, locale: Locale::DEFAULT)
      copy = COPY.fetch(Locale.normalize(locale))
      auth = AUTH_COPY.fetch(Locale.normalize(locale))
      Screen.new(
        text: "aiaiaiai ecosystem × 0x1\n\n#{auth.fetch(:pending)}",
        reply_markup: { inline_keyboard: [[
          { text: copy.fetch(:back), callback_data: "v:#{sku}" },
          { text: copy.fetch(:home), callback_data: "h:b" }
        ]] }
      )
    end

    def balance_unavailable(locale:)
      AUTH_COPY.fetch(Locale.normalize(locale)).fetch(:offline)
    end

    def build(product:, locale: Locale::DEFAULT, seed_balance: nil)
      metadata = product.dig("attributes", "metadata") || {}
      raise ArgumentError, "not a 0x1 subscription" unless metadata["family"] == "0x1_subscription"

      sku = product.fetch("id")
      copy = COPY.fetch(Locale.normalize(locale))
      seed_price = metadata["seed_price"]
      amount = seed_price.is_a?(Hash) && seed_price["currency"] == "seeds" ? seed_price["amount"] : nil
      seeds = valid_seed_amount(amount) ? "#{amount} #{seeds_noun(amount, locale)}" : "— ₴€£"
      localized_price = product.dig("attributes", "preview_price")
      money = formatted_money(localized_price)
      balance_button = if valid_balance(seed_balance)
                         { text: "#{copy.fetch(:balance)}: #{seed_balance} ₴€£", callback_data: "z:#{sku}" }
                       elsif seed_balance == :unavailable
                         { text: balance_unavailable(locale: locale), callback_data: "z:#{sku}" }
                       else
                         { text: AUTH_COPY.fetch(Locale.normalize(locale)).fetch(:sign_in), callback_data: "z:#{sku}" }
                       end

      rows = [
        [
          { text: "•", callback_data: "n" },
          { text: copy.fetch(:buy_for), callback_data: "n" },
          { text: "•", callback_data: "n" }
        ],
        [
          { text: seeds, callback_data: "x:#{sku}" },
          { text: money, callback_data: "y:#{sku}" }
        ],
        [
          { text: copy.fetch(:back), callback_data: "c:b:#{sku}" },
          { text: copy.fetch(:home), callback_data: "h:b" },
          balance_button
        ]
      ]
      Screen.new(
        text: "#{product.dig("attributes", "name")}\n\n#{copy.fetch(:preview)}",
        reply_markup: { inline_keyboard: rows }
      )
    end

    private

    def seeds_noun(amount, locale)
      normalized = Locale.normalize(locale)
      if normalized == "uk_UA" || normalized == "ru_RU"
        remainder = amount % 100
        many = (11..14).cover?(remainder)
        form = if !many && amount % 10 == 1
                 0
               elsif !many && (2..4).cover?(amount % 10)
                 1
               else
                 2
               end
        return (normalized == "uk_UA" ? %w[сід сіди сідів] : %w[сид сида сидов]).fetch(form)
      end

      normalized == "en_US" ? (amount == 1 ? "seed" : "seeds") : "₴€£"
    end

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
