# frozen_string_literal: true

require_relative "namespace"

require "json"
require "rack"
require_relative "market_api"
require_relative "purchase_flow"
require_relative "telegram_web_app_auth"

module ZeroXDA::Market::TelegramBot
    class TelegramMiniApp
      JSON_HEADERS = {
        "content-type" => "application/json; charset=utf-8",
        "cache-control" => "no-store"
      }.freeze
      ASSET_CACHE = "public, max-age=300, stale-while-revalidate=3600"
      CONTENT_SECURITY_POLICY = [
        "default-src 'self'",
        "script-src 'self' https://telegram.org https://cdn.jsdelivr.net",
        "style-src 'self'",
        "connect-src 'self'",
        "img-src 'self' data: https:",
        "font-src 'self' data:"
      ].join("; ").freeze
      RESOURCE_ID_PATTERN = /\A[A-Za-z0-9:_-]{1,80}\z/

      def initialize(service:, root:)
        @service = service
        @files = Rack::Files.new(File.expand_path(root))
      end

      def call(environment)
        request = Rack::Request.new(environment)
        return redirect_to_index if request.get? && request.path_info == "/webapp"
        return bootstrap(request) if request.get? && request.path_info == "/webapp/bootstrap"
        return quote(request) if request.post? && request.path_info == "/webapp/quotes"
        return broker_listings(request) if request.get? && request.path_info == "/webapp/broker/listings"
        return create_broker_listing(request) if request.post? && request.path_info == "/webapp/broker/listings"
        return admin_products(request) if request.get? && request.path_info == "/webapp/admin/products"
        return create_admin_product(request) if request.post? && request.path_info == "/webapp/admin/products"
        return admin_price_proposal(request) if request.get? && request.path_info == "/webapp/admin/prices/proposal"
        return admin_price_history(request) if request.get? && request.path_info == "/webapp/admin/prices/history"
        return apply_admin_prices(request) if request.post? && request.path_info == "/webapp/admin/prices"

        if request.post? && (match = request.path_info.match(%r{\A/webapp/quotes/([^/]+)/accept\z}))
          return accept(request, resource_id(match[1]))
        end
        if request.get? && (match = request.path_info.match(%r{\A/webapp/orders/([^/]+)\z}))
          return refresh(request, resource_id(match[1]))
        end
        if request.patch? && (match = request.path_info.match(%r{\A/webapp/broker/listings/([^/]+)\z}))
          return update_broker_listing(request, resource_id(match[1]))
        end
        if request.delete? && (match = request.path_info.match(%r{\A/webapp/broker/listings/([^/]+)\z}))
          return withdraw_broker_listing(request, resource_id(match[1]))
        end
        if request.patch? && (match = request.path_info.match(%r{\A/webapp/admin/products/([^/]+)\z}))
          return update_admin_product(request, resource_id(match[1]))
        end
        localization_match = request.path_info.match(
          %r{\A/webapp/admin/products/([^/]+)/localizations/([^/]+)\z}
        )
        if request.put? && localization_match
          return save_admin_product_localization(
            request,
            resource_id(localization_match[1]),
            resource_id(localization_match[2])
          )
        end

        return static_asset(request, environment) if request.get? || request.head?

        json_response(404, error: "not_found")
      rescue TelegramWebAppAuth::Invalid => error
        json_response(401, error: "invalid_telegram_session", message: error.message)
      rescue PurchaseFlow::AccessDenied => error
        json_response(403, error: "access_denied", message: error.message)
      rescue PurchaseFlow::UnpricedProduct, ArgumentError => error
        json_response(422, error: "invalid_request", message: error.message)
      rescue MarketAPI::Error => error
        json_response(error.status, error: error.code, message: error.message)
      rescue JSON::ParserError
        json_response(400, error: "invalid_json")
      end

      private

      def bootstrap(request)
        document = @service.bootstrap(
          init_data: init_data(request),
          locale: request.params["locale"]
        )
        json_document(200, document)
      end

      def quote(request)
        body = request_document(request)
        document = @service.quote(
          init_data: init_data(request),
          sku: body.fetch("sku"),
          quantity: body.fetch("quantity", 1),
          locale: body["locale"]
        )
        json_document(201, document)
      end

      def accept(request, quote_id)
        request_document(request, allow_empty: true)
        document = @service.accept(init_data: init_data(request), quote_id: quote_id)
        json_document(201, document)
      end

      def refresh(request, order_id)
        document = @service.refresh(init_data: init_data(request), order_id: order_id)
        json_document(200, document)
      end

      def broker_listings(request)
        json_document(200, @service.broker_listings(init_data: init_data(request)))
      end

      def create_broker_listing(request)
        body = request_document(request)
        document = @service.create_broker_listing(
          init_data: init_data(request),
          sku: body.fetch("sku"),
          quantity: body.fetch("quantity"),
          price_amount: body.fetch("price_amount"),
          currency: body.fetch("currency")
        )
        json_document(201, document)
      end

      def update_broker_listing(request, listing_id)
        body = request_document(request)
        document = @service.update_broker_listing(
          init_data: init_data(request),
          listing_id: listing_id,
          quantity: body.fetch("quantity"),
          price_amount: body.fetch("price_amount"),
          currency: body.fetch("currency"),
          version: body.fetch("version")
        )
        json_document(200, document)
      end

      def withdraw_broker_listing(request, listing_id)
        body = request_document(request)
        document = @service.withdraw_broker_listing(
          init_data: init_data(request),
          listing_id: listing_id,
          version: body.fetch("version")
        )
        json_document(200, document)
      end

      def admin_products(request)
        document = @service.admin_products(
          init_data: init_data(request),
          locale: request.params["locale"]
        )
        json_document(200, document)
      end

      def create_admin_product(request)
        body = request_document(request)
        document = @service.create_admin_product(
          init_data: init_data(request),
          sku: body.fetch("sku"),
          attributes: body.fetch("attributes"),
          localization: body.fetch("localization")
        )
        json_document(201, document)
      end

      def update_admin_product(request, sku)
        body = request_document(request)
        document = @service.update_admin_product(
          init_data: init_data(request),
          sku: sku,
          version: body.fetch("version"),
          attributes: body.fetch("attributes")
        )
        json_document(200, document)
      end

      def save_admin_product_localization(request, sku, locale)
        body = request_document(request)
        document = @service.save_admin_product_localization(
          init_data: init_data(request),
          sku: sku,
          locale: locale,
          full_name: body.fetch("full_name"),
          button_label: body.fetch("button_label"),
          version: body["version"]
        )
        json_document(body.key?("version") ? 200 : 201, document)
      end

      def admin_price_proposal(request)
        document = @service.admin_price_proposal(
          init_data: init_data(request),
          locale: request.params["locale"]
        )
        json_document(200, document)
      end

      def admin_price_history(request)
        document = @service.admin_price_history(
          init_data: init_data(request),
          limit: request.params.fetch("limit", 20)
        )
        json_document(200, document)
      end

      def apply_admin_prices(request)
        body = request_document(request)
        document = @service.apply_admin_prices(
          init_data: init_data(request),
          revision: body.fetch("revision"),
          prices: body.fetch("prices")
        )
        json_document(201, document)
      end

      def init_data(request)
        request.get_header("HTTP_X_TELEGRAM_INIT_DATA").to_s
      end

      def request_document(request, allow_empty: false)
        body = request.body.read(65_537)
        return {} if allow_empty && body.empty?
        raise ArgumentError, "request body is too large" if body.bytesize > 65_536

        document = JSON.parse(body)
        raise ArgumentError, "request body must be an object" unless document.is_a?(Hash)

        document
      end

      def resource_id(value)
        id = value.to_s
        raise ArgumentError, "resource id is invalid" unless RESOURCE_ID_PATTERN.match?(id)

        id
      end

      def redirect_to_index
        [
          302,
          {
            "location" => "/webapp/",
            "cache-control" => "no-store",
            "content-length" => "0"
          },
          []
        ]
      end

      def static_asset(request, environment)
        path = request.path_info.delete_prefix("/webapp")
        path = "/index.html" if path.empty? || path == "/"
        status, headers, body = @files.call(environment.merge("PATH_INFO" => path))
        return json_response(404, error: "not_found") unless status == 200

        cache_control = path == "/index.html" ? "no-store" : ASSET_CACHE
        [
          status,
          headers.merge(
            "cache-control" => cache_control,
            "content-security-policy" => CONTENT_SECURITY_POLICY,
            "x-content-type-options" => "nosniff"
          ),
          body
        ]
      end

      def json_document(status, document)
        [status, JSON_HEADERS, [JSON.generate(document)]]
      end

      def json_response(status, **document)
        json_document(status, document)
      end
    end
end
