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
        "script-src 'self' https://telegram.org",
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

        if request.post? && (match = request.path_info.match(%r{\A/webapp/quotes/([^/]+)/accept\z}))
          return accept(request, resource_id(match[1]))
        end
        if request.get? && (match = request.path_info.match(%r{\A/webapp/orders/([^/]+)\z}))
          return refresh(request, resource_id(match[1]))
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
        json_response(502, error: error.code, message: error.message)
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
