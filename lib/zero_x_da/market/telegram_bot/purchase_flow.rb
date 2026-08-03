# frozen_string_literal: true

require_relative "namespace"

module ZeroXDA::Market::TelegramBot
    class PurchaseFlow
      class AccessDenied < StandardError; end
      class UnpricedProduct < StandardError; end

      def initialize(market_api:)
        @market_api = market_api
      end

      def quote(sku:, quantity:, user:, telegram_user:, chat:, locale:)
        @market_api.create_marketplace_quote(
          actor_user_id: user.fetch("id"),
          sku: sku,
          quantity: quantity,
          context: ownership_context(
            user: user,
            telegram_user: telegram_user,
            chat: chat,
            locale: locale
          )
        )
      end

      def accept(quote_id:, user:)
        order = @market_api.accept_marketplace_quote(
          actor_user_id: user.fetch("id"),
          quote_id: quote_id
        )
        @market_api.execute_marketplace_order(
          actor_user_id: user.fetch("id"),
          order_id: order.fetch("id")
        )
      end

      def refresh(order_id:, user:)
        order = @market_api.marketplace_order(
          actor_user_id: user.fetch("id"),
          order_id: order_id
        )
        return order unless executable?(order)

        @market_api.execute_marketplace_order(
          actor_user_id: user.fetch("id"),
          order_id: order.fetch("id")
        )
      end

      private

      def ownership_context(user:, telegram_user:, chat:, locale:)
        {
          channel: "telegram",
          telegram: {
            user_id: telegram_user.fetch("id").to_s,
            chat_id: chat.fetch("id").to_s
          },
          locale: locale
        }
      end

      def executable?(order)
        attributes = order.fetch("attributes")
        return true if %w[accepted pending].include?(attributes.fetch("status"))

        attributes.fetch("status") == "failed" && attributes.dig("failure", "retryable")
      end
    end
end
