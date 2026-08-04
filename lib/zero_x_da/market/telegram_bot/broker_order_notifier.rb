# frozen_string_literal: true

require_relative "namespace"

module ZeroXDA::Market::TelegramBot
  class BrokerOrderNotifier
    COPY = {
      "broker_order_accepted" => {
        "uk" => ->(name, quantity) { "Broker погодився виконати замовлення ✅\n#{name} · #{quantity}" },
        "en" => ->(name, quantity) { "The broker accepted your order ✅\n#{name} · #{quantity}" }
      },
      "broker_order_completed" => {
        "uk" => ->(name, quantity) { "Замовлення виконано ✅\n#{name} · #{quantity}" },
        "en" => ->(name, quantity) { "Your order is complete ✅\n#{name} · #{quantity}" }
      }
    }.freeze

    def initialize(market_api:, telegram_api:, logger: $stderr)
      @market_api = market_api
      @telegram_api = telegram_api
      @logger = logger
    end

    def deliver(resource, actor_user_id:)
      meta = resource.fetch("meta", {})
      event = meta["notification_event"]
      recipient_id = meta["notification_recipient_user_id"]
      return public_resource(resource) unless event && recipient_id

      profile = @market_api.active_users.find { |entry| entry.fetch("id") == recipient_id }
      attributes = profile&.fetch("attributes", {}) || {}
      chat_id = attributes["telegram_chat_id"]
      return public_resource(resource) if chat_id.to_s.empty?

      locale = String(attributes["language_code"]).downcase.start_with?("uk") ? "uk" : "en"
      order = resource.fetch("attributes")
      text = COPY.fetch(event).fetch(locale).call(order["product_name"] || order["sku"], order["quantity"])
      @telegram_api.send_message(chat_id: chat_id, text: text)
      @market_api.acknowledge_broker_order_notification(
        actor_user_id: actor_user_id,
        order_id: resource.fetch("id"),
        event: event
      )
      public_resource(resource)
    rescue StandardError => error
      @logger.puts("broker order notification failed: #{error.class}: #{error.message}")
      public_resource(resource)
    end

    private

    def public_resource(resource)
      resource.reject { |key, _value| key == "meta" }
    end
  end
end
