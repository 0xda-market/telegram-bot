# frozen_string_literal: true

require_relative "namespace"
require_relative "bot"
require_relative "status_cards"

module ZeroXDA::Market::TelegramBot
  module MiniAppEntryPoint
    BUTTON_TEXT = "🛍️ 0xda-market"

    def initialize(*arguments, web_app_url: nil, **keywords)
      @web_app_url = normalize_web_app_url(web_app_url)
      super(*arguments, **keywords)
    end

    private

    def status_card_keyboard(callback_data, locale:)
      reply_markup = super
      return reply_markup unless @web_app_url

      rows = reply_markup.fetch(:inline_keyboard).map(&:dup)
      rows.unshift(
        [
          {
            text: BUTTON_TEXT,
            web_app: { url: @web_app_url }
          }
        ]
      )
      reply_markup.merge(inline_keyboard: rows)
    end

    def normalize_web_app_url(value)
      normalized = value.to_s.strip
      normalized.empty? ? nil : normalized
    end
  end

  Bot.prepend(MiniAppEntryPoint)
end
