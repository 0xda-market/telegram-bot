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

      def admin_products(actor_user_id:, locale: "en_US")
        get(
          "v1/admin/products?#{URI.encode_www_form(actor_user_id: actor_user_id, locale: locale)}",
          authenticated: true
        ).fetch("data")
      end

      def update_admin_product(actor_user_id:, sku:, version:, attributes:)
        patch(
          "v1/admin/products/#{resource_id(sku)}",
          actor_user_id: actor_user_id,
          version: version,
          attributes: attributes
        ).fetch("data")
      end

      def save_admin_product_localization(
        actor_user_id:,
        sku:,
        locale:,
        full_name:,
        button_label:,
        version: nil
      )
        payload = {
          actor_user_id: actor_user_id,
          full_name: full_name,
          button_label: button_label
        }
        payload[:version] = version unless version.nil?
        write_request(
          Net::HTTP::Put,
          "v1/admin/products/#{resource_id(sku)}/localizations/#{resource_id(locale)}",
          payload
        ).fetch("data")
      end
    end
end
