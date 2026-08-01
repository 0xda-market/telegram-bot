# frozen_string_literal: true

require_relative "namespace"

require_relative "locale"
require_relative "market_api_webapp"
require_relative "purchase_flow"
require_relative "telegram_web_app_auth"

module ZeroXDA::Market::TelegramBot
    class TelegramWebAppService
      def initialize(market_api:, authentication:, purchase_flow: PurchaseFlow.new(market_api: market_api), environment: "development")
        @market_api = market_api
        @authentication = authentication
        @purchase_flow = purchase_flow
        @environment = environment.to_s
      end

      def bootstrap(init_data:, locale:)
        session, user = authenticate(init_data)
        selected_locale = normalized_locale(locale)
        document = @market_api.webapp_bootstrap(locale: selected_locale, currency: "USDT")
        public_session = {
          "role" => user.dig("attributes", "role"),
          "status" => user.dig("attributes", "status"),
          "subject" => session.subject,
          "environment" => @environment
        }
        document.merge(
          "meta" => document.fetch("meta").merge(
            "channel" => "telegram",
            "session" => public_session,
            "user" => public_session.slice("role", "status"),
            "currencies" => @market_api.currencies(locale: selected_locale),
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
        { "data" => quote, "meta" => { "snapshot_id" => catalog.dig("meta", "snapshot_id") } }
      end

      def accept(init_data:, quote_id:)
        _session, user = authenticate(init_data)
        { "data" => @purchase_flow.accept(quote_id: quote_id, user: user) }
      end

      def refresh(init_data:, order_id:)
        _session, user = authenticate(init_data)
        { "data" => @purchase_flow.refresh(order_id: order_id, user: user) }
      end

      def broker_listings(init_data:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.broker_listings(actor_user_id: user.fetch("id")) }
      end

      def create_broker_listing(init_data:, sku:, quantity:, price_amount:, currency:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.create_broker_listing(
          actor_user_id: user.fetch("id"),
          sku: sku,
          quantity: quantity,
          price_amount: price_amount,
          currency: currency
        ) }
      end

      def update_broker_listing(init_data:, listing_id:, quantity:, price_amount:, currency:, version:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.update_broker_listing(
          actor_user_id: user.fetch("id"),
          listing_id: listing_id,
          quantity: quantity,
          price_amount: price_amount,
          currency: currency,
          version: version
        ) }
      end

      def withdraw_broker_listing(init_data:, listing_id:, version:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.withdraw_broker_listing(
          actor_user_id: user.fetch("id"),
          listing_id: listing_id,
          version: version
        ) }
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
