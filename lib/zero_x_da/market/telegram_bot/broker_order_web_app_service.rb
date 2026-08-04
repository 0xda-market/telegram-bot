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
      actor_id = user.fetch("id")
      resources = @market_api.broker_orders(actor_user_id: actor_id)
      { "data" => resources.map { |resource| notify(resource, actor_user_id: actor_id) } }
    end

    def accept_broker_order(init_data:, order_id:, version:)
      _session, user = authenticate(init_data)
      actor_id = user.fetch("id")
      resource = @market_api.accept_broker_order(
        actor_user_id: actor_id, order_id: order_id, version: version
      )
      { "data" => notify(resource, actor_user_id: actor_id) }
    end

    def complete_broker_order(init_data:, order_id:, version:, reference: nil, data: {})
      _session, user = authenticate(init_data)
      actor_id = user.fetch("id")
      resource = @market_api.complete_broker_order(
        actor_user_id: actor_id, order_id: order_id, version: version,
        reference: reference, data: data
      )
      { "data" => notify(resource, actor_user_id: actor_id) }
    end

    private

    def notify(resource, actor_user_id:)
      return resource.reject { |key, _| key == "meta" } unless @broker_order_notifier

      @broker_order_notifier.deliver(resource, actor_user_id: actor_user_id)
    end
  end

  TelegramWebAppService.prepend(BrokerOrderWebAppService)
end
