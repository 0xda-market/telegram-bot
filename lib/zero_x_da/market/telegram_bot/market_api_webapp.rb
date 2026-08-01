# frozen_string_literal: true

require_relative "namespace"

require_relative "market_api"

module ZeroXDA::Market::TelegramBot
    class MarketAPI
      def webapp_bootstrap(locale: "en_US", currency: "USDT")
        get(
          "v1/webapp/bootstrap?#{URI.encode_www_form(locale: locale, currency: currency)}",
          authenticated: false
        )
      end
    end
end
