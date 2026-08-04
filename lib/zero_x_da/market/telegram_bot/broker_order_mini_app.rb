# frozen_string_literal: true

require "rack"
require_relative "telegram_mini_app"

module ZeroXDA::Market::TelegramBot
  module BrokerOrderMiniApp
    def call(environment)
      request = Rack::Request.new(environment)
      return broker_orders(request) if request.get? && request.path_info == "/webapp/broker/orders"

      if request.post? && (match = request.path_info.match(%r{\A/webapp/broker/orders/([^/]+)/accept\z}))
        return accept_broker_order(request, resource_id(match[1]))
      end
      if request.post? && (match = request.path_info.match(%r{\A/webapp/broker/orders/([^/]+)/complete\z}))
        return complete_broker_order(request, resource_id(match[1]))
      end

      super
    rescue TelegramWebAppAuth::Invalid => error
      json_response(401, status: "error", error: "invalid_telegram_session", message: error.message)
    rescue PurchaseFlow::AccessDenied => error
      json_response(403, status: "error", error: "access_denied", message: error.message)
    rescue MarketAPI::Error => error
      json_response(error.status, status: "error", error: error.code, message: error.message)
    rescue ArgumentError => error
      json_response(422, status: "error", error: "invalid_request", message: error.message)
    rescue JSON::ParserError
      json_response(400, status: "error", error: "invalid_json")
    end

    private

    def broker_orders(request)
      json_document(200, @service.broker_orders(init_data: init_data(request)))
    end

    def accept_broker_order(request, order_id)
      body = request_document(request)
      post_document(200, @service.accept_broker_order(
        init_data: init_data(request), order_id: order_id, version: body.fetch("version")
      ))
    end

    def complete_broker_order(request, order_id)
      body = request_document(request)
      post_document(200, @service.complete_broker_order(
        init_data: init_data(request), order_id: order_id, version: body.fetch("version"),
        reference: body["reference"], data: body.fetch("data", {})
      ))
    end
  end

  TelegramMiniApp.prepend(BrokerOrderMiniApp)
end
