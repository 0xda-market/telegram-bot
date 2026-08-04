# frozen_string_literal: true

require_relative "telegram_web_app_service"

module ZeroXDA::Market::TelegramBot
  module BrokerOrderWebAppService
    def initialize(broker_order_notifier: nil, **options)
      @broker_order_notifier = broker_order_notifier
      super(**options)
    end

    def broker_orders(init_data:)
      _session, user = authenticate(init_data)
      { "data" => @market_api.broker_orders(actor_user_id: user.fetch("id")) }
    end

    def accept_broker_order(init_data:, order_id:, version:)
      _session, user = authenticate(init_data)
      resource = @market_api.accept_broker_order(
        actor_user_id: user.fetch("id"),
        order_id: order_id,
        version: version
      )
      { "data" => notify(resource) }
    end

    def complete_broker_order(init_data:, order_id:, version:, reference: nil, data: {})
      _session, user = authenticate(init_data)
      resource = @market_api.complete_broker_order(
        actor_user_id: user.fetch("id"),
        order_id: order_id,
        version: version,
        reference: reference,
        data: data
      )
      { "data" => notify(resource) }
    end

    private

    def notify(resource)
      @broker_order_notifier ? @broker_order_notifier.deliver(resource) : resource.reject { |key, _| key == "meta" }
    end
  end

  TelegramWebAppService.prepend(BrokerOrderWebAppService)
end
