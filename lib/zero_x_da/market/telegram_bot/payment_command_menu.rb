# frozen_string_literal: true

require_relative "namespace"
require_relative "command_menu"

module ZeroXDA::Market::TelegramBot
  module PaymentCommandMenu
    SUPPORT_COPY = {
      "en_US" => "⭐ payment support",
      "uk_UA" => "⭐ підтримка оплати",
      "ru_RU" => "⭐ поддержка оплаты",
      "fr_FR" => "⭐ assistance paiement",
      "es_ES" => "⭐ soporte de pagos",
      "de_DE" => "⭐ Zahlungssupport"
    }.freeze

    private

    def sync_commands(chat_id, user)
      return super unless @payments

      locale = user.dig("attributes", "locale") || @telegram_update_locale || Locale::DEFAULT
      commands = admin?(user) ? CommandMenu.admin(locale: locale) : CommandMenu.client(locale: locale)
      commands = commands + [
        { command: "terms", description: @payment_terms.command_description(locale: locale) },
        { command: "paysupport", description: SUPPORT_COPY.fetch(Locale.normalize(locale), SUPPORT_COPY.fetch(Locale::DEFAULT)) }
      ]
      @telegram_api.set_commands(commands, scope: { type: "chat", chat_id: chat_id })
    rescue TelegramAPI::Error => error
      warn "command menu sync failed: #{error.message}"
    end
  end

  Bot.prepend(PaymentCommandMenu)
end
