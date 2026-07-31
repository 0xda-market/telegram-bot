# frozen_string_literal: true

require_relative "market_api"

module ZeroXDA
  module MarketClientBot
    class MarketAPI
      def webapp_bootstrap(locale: "en_US", currency: "USDT")
        get(
          "v1/webapp/bootstrap?#{URI.encode_www_form(locale: locale, currency: currency)}",
          authenticated: false
        )
      end
    end
  end
end
