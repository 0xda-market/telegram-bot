# frozen_string_literal: true

require_relative "namespace"
require_relative "market_api"

module ZeroXDA::Market::TelegramBot
  class MarketAPI
    def webapp_bootstrap(locale: "en_US", currency: "USDT")
      get("v1/webapp/bootstrap?#{URI.encode_www_form(locale: locale, currency: currency)}", authenticated: false)
    end

    def create_marketplace_quote(actor_user_id:, sku:, quantity:, context:)
      post("v1/market/quotes", actor_user_id: actor_user_id, sku: sku, quantity: quantity, context: context).fetch("data")
    end

    def accept_marketplace_quote(actor_user_id:, quote_id:)
      post("v1/market/quotes/#{resource_id(quote_id)}/accept", actor_user_id: actor_user_id).fetch("data")
    end

    def marketplace_order(actor_user_id:, order_id:)
      get("v1/market/orders/#{resource_id(order_id)}?#{URI.encode_www_form(actor_user_id: actor_user_id)}", authenticated: true).fetch("data")
    end

    def execute_marketplace_order(actor_user_id:, order_id:)
      post("v1/market/orders/#{resource_id(order_id)}/execute", actor_user_id: actor_user_id).fetch("data")
    end

    def broker_orders(actor_user_id:)
      get("v1/broker/orders?#{URI.encode_www_form(actor_user_id: actor_user_id)}", authenticated: true).fetch("data")
    end

    def accept_broker_order(actor_user_id:, order_id:, version:)
      post("v1/broker/orders/#{resource_id(order_id)}/accept", actor_user_id: actor_user_id, version: version).fetch("data")
    end

    def complete_broker_order(actor_user_id:, order_id:, version:, reference: nil, data: {})
      document = post(
        "v1/broker/orders/#{resource_id(order_id)}/complete",
        actor_user_id: actor_user_id,
        version: version,
        reference: reference,
        data: data
      )
      document.fetch("data")
    end

    def admin_products(actor_user_id:, locale: "en_US")
      get("v1/admin/products?#{URI.encode_www_form(actor_user_id: actor_user_id, locale: locale)}", authenticated: true).fetch("data")
    end

    def create_admin_product(actor_user_id:, sku:, attributes:, localization:)
      post("v1/admin/products", actor_user_id: actor_user_id, sku: sku, attributes: attributes, localization: localization).fetch("data")
    end

    def update_admin_product(actor_user_id:, sku:, version:, attributes:)
      patch("v1/admin/products/#{resource_id(sku)}", actor_user_id: actor_user_id, version: version, attributes: attributes).fetch("data")
    end

    def save_admin_product_localization(actor_user_id:, sku:, locale:, full_name:, button_label:, version: nil)
      payload = { actor_user_id: actor_user_id, full_name: full_name, button_label: button_label }
      payload[:version] = version unless version.nil?
      write_request(Net::HTTP::Put, "v1/admin/products/#{resource_id(sku)}/localizations/#{resource_id(locale)}", payload).fetch("data")
    end

    def admin_price_proposal(actor_user_id:, locale: "en_US")
      get("v1/admin/prices/proposal?#{URI.encode_www_form(actor_user_id: actor_user_id, locale: locale)}", authenticated: true)
    end

    def admin_price_history(actor_user_id:, limit: 20)
      get("v1/admin/prices/history?#{URI.encode_www_form(actor_user_id: actor_user_id, limit: limit)}", authenticated: true)
    end

    def apply_admin_prices(actor_user_id:, revision:, prices:)
      post("v1/admin/prices", actor_user_id: actor_user_id, revision: revision, prices: prices)
    end
  end
end
