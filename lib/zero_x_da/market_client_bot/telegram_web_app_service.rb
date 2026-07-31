# frozen_string_literal: true

require_relative "locale"
require_relative "market_api_webapp"
require_relative "purchase_flow"
require_relative "telegram_web_app_auth"

module ZeroXDA
  module MarketClientBot
    class TelegramWebAppService
      def initialize(market_api:, authentication:, purchase_flow: PurchaseFlow.new(market_api: market_api))
        @market_api = market_api
        @authentication = authentication
        @purchase_flow = purchase_flow
      end

      def bootstrap(init_data:, locale:)
        session, user = authenticate(init_data)
        document = @market_api.webapp_bootstrap(locale: normalized_locale(locale), currency: "USDT")
        document.merge(
          "meta" => document.fetch("meta").merge(
            "channel" => "telegram",
            "user" => {
              "id" => user.fetch("id"),
              "role" => user.dig("attributes", "role"),
              "status" => user.dig("attributes", "status")
            },
            "telegram_auth_date" => session.auth_date.iso8601(6)
          )
        )
      end

      def quote(init_data:, sku:, locale:)
        session, user = authenticate(init_data)
        selected_locale = normalized_locale(locale)
        catalog = @market_api.webapp_bootstrap(locale: selected_locale, currency: "USDT")
        product = catalog.fetch("data").find { |entry| entry.fetch("id") == sku.to_s }
        raise ArgumentError, "product is unavailable" unless product

        _intent, quote = @purchase_flow.quote(
          product: product,
          user: user,
          telegram_user: session.user,
          chat: session.chat,
          locale: selected_locale
        )
        {
          "data" => quote,
          "meta" => { "snapshot_id" => catalog.dig("meta", "snapshot_id") }
        }
      end

      def accept(init_data:, quote_id:)
        _session, user = authenticate(init_data)
        { "data" => @purchase_flow.accept(quote_id: quote_id, user: user) }
      end

      def refresh(init_data:, order_id:)
        _session, user = authenticate(init_data)
        { "data" => @purchase_flow.refresh(order_id: order_id, user: user) }
      end

      private

      def authenticate(init_data)
        session = @authentication.verify(init_data)
        user = @market_api.authenticate_telegram(user: session.user, chat: session.chat)
        [session, user]
      end

      def normalized_locale(locale)
        Locale.normalize(locale)
      end
    end
  end
end
