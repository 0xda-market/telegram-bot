# frozen_string_literal: true

require_relative "namespace"

module ZeroXDA::Market::TelegramBot
    class PurchaseFlow
      CAPABILITY = "manual.fulfillment"

      class AccessDenied < StandardError; end
      class UnpricedProduct < StandardError; end

      def initialize(market_api:)
        @market_api = market_api
      end

      def quote(product:, user:, telegram_user:, chat:, locale:)
        price = product.dig("attributes", "price")
        amount_usdt = price && price["amount_usdt"]
        raise UnpricedProduct, "product has no active price" if amount_usdt.to_s.empty?

        intent = @market_api.create_intent(
          capability: CAPABILITY,
          payload: {
            action: "purchase",
            product: {
              sku: product.fetch("id"),
              name: product.dig("attributes", "name"),
              amount_usdt: amount_usdt,
              currency: "USDT"
            }
          },
          context: ownership_context(
            user: user,
            telegram_user: telegram_user,
            chat: chat,
            locale: locale
          )
        )
        [intent, @market_api.quote_intent(intent.fetch("id"))]
      end

      def accept(quote_id:, user:)
        quote = @market_api.quote(quote_id)
        intent = @market_api.intent(quote.dig("attributes", "intent_id"))
        require_owner!(intent.dig("attributes", "context"), user)
        order = @market_api.accept_quote(quote_id)
        @market_api.execute_order(order.fetch("id"))
      end

      def refresh(order_id:, user:)
        order = @market_api.order(order_id)
        require_owner!(order.dig("attributes", "context"), user)
        return order unless executable?(order)

        @market_api.execute_order(order.fetch("id"))
      end

      private

      def ownership_context(user:, telegram_user:, chat:, locale:)
        {
          customer_user_id: user.fetch("id"),
          channel: "telegram",
          telegram: {
            user_id: telegram_user.fetch("id").to_s,
            chat_id: chat.fetch("id").to_s
          },
          locale: locale
        }
      end

      def require_owner!(context, user)
        owner = context&.fetch("customer_user_id", nil).to_s
        raise AccessDenied, "purchase belongs to another user" unless owner == user.fetch("id").to_s
      end

      def executable?(order)
        attributes = order.fetch("attributes")
        return true if %w[accepted pending].include?(attributes.fetch("status"))

        attributes.fetch("status") == "failed" && attributes.dig("failure", "retryable")
      end
    end
end
