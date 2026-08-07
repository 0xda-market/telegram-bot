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

      def quote(init_data:, sku:, quantity:, locale:, recipient: nil)
        session, user = authenticate(init_data)
        quote = @purchase_flow.quote(
          sku: sku,
          quantity: quantity,
          recipient: recipient,
          user: user,
          telegram_user: session.user,
          chat: session.chat,
          locale: normalized_locale(locale)
        )
        { "data" => quote }
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

      def admin_products(init_data:, locale:)
        _session, user = authenticate(init_data)
        {
          "data" => @market_api.admin_products(
            actor_user_id: user.fetch("id"),
            locale: normalized_locale(locale)
          )
        }
      end

      def create_admin_product(init_data:, sku:, attributes:, localization:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.create_admin_product(actor_user_id: user.fetch("id"), sku: sku, attributes: attributes, localization: localization) }
      end

      def update_admin_product(init_data:, sku:, version:, attributes:)
        _session, user = authenticate(init_data)
        { "data" => @market_api.update_admin_product(actor_user_id: user.fetch("id"), sku: sku, version: version, attributes: attributes) }
      end

      def save_admin_product_localization(init_data:, sku:, locale:, full_name:, button_label:, version: nil)
        _session, user = authenticate(init_data)
        { "data" => @market_api.save_admin_product_localization(actor_user_id: user.fetch("id"), sku: sku, locale: locale,
                                                                  full_name: full_name, button_label: button_label, version: version) }
      end

      def admin_price_proposal(init_data:, locale:)
        _session, user = authenticate(init_data)
        @market_api.admin_price_proposal(actor_user_id: user.fetch("id"), locale: normalized_locale(locale))
      end

      def admin_price_history(init_data:, limit:)
        _session, user = authenticate(init_data)
        @market_api.admin_price_history(actor_user_id: user.fetch("id"), limit: limit)
      end

      def apply_admin_prices(init_data:, revision:, prices:)
        _session, user = authenticate(init_data)
        @market_api.apply_admin_prices(actor_user_id: user.fetch("id"), revision: revision, prices: prices)
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
