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

      # `product:` remains accepted for the existing inline bot purchase
      # callback. The Mini App sends `sku:` and `quantity:` directly. Both
      # surfaces use the marketplace API when the connected core supports it.
      def quote(
        user:,
        telegram_user:,
        chat:,
        locale:,
        sku: nil,
        quantity: "1",
        product: nil
      )
        if marketplace_api?
          resource = @market_api.create_marketplace_quote(
            actor_user_id: user.fetch("id"),
            sku: sku || product&.fetch("id"),
            quantity: quantity,
            context: ownership_context(
              user: user,
              telegram_user: telegram_user,
              chat: chat,
              locale: locale,
              include_customer: false
            )
          )
          return product ? [nil, resource] : resource
        end

        legacy_quote(
          product: product,
          user: user,
          telegram_user: telegram_user,
          chat: chat,
          locale: locale
        )
      end

      def accept(quote_id:, user:)
        return legacy_accept(quote_id: quote_id, user: user) unless marketplace_api?

        order = @market_api.accept_marketplace_quote(
          actor_user_id: user.fetch("id"),
          quote_id: quote_id
        )
        return order if payment_pending?(order)

        @market_api.execute_marketplace_order(
          actor_user_id: user.fetch("id"),
          order_id: order.fetch("id")
        )
      end

      def refresh(order_id:, user:)
        return legacy_refresh(order_id: order_id, user: user) unless marketplace_api?

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

      def marketplace_api?
        @market_api.respond_to?(:create_marketplace_quote) &&
          @market_api.respond_to?(:accept_marketplace_quote) &&
          @market_api.respond_to?(:marketplace_order) &&
          @market_api.respond_to?(:execute_marketplace_order)
      end

      def legacy_quote(product:, user:, telegram_user:, chat:, locale:)
        raise ArgumentError, "product is required" unless product

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
            locale: locale,
            include_customer: true
          )
        )
        [intent, @market_api.quote_intent(intent.fetch("id"))]
      end

      def legacy_accept(quote_id:, user:)
        quote = @market_api.quote(quote_id)
        intent = @market_api.intent(quote.dig("attributes", "intent_id"))
        require_owner!(intent.dig("attributes", "context"), user)
        order = @market_api.accept_quote(quote_id)
        @market_api.execute_order(order.fetch("id"))
      end

      def legacy_refresh(order_id:, user:)
        order = @market_api.order(order_id)
        require_owner!(order.dig("attributes", "context"), user)
        return order unless executable?(order)

        @market_api.execute_order(order.fetch("id"))
      end

      def ownership_context(user:, telegram_user:, chat:, locale:, include_customer:)
        context = {
          channel: "telegram",
          telegram: {
            user_id: telegram_user.fetch("id").to_s,
            chat_id: chat.fetch("id").to_s
          },
          locale: locale
        }
        context[:customer_user_id] = user.fetch("id") if include_customer
        context
      end

      def require_owner!(context, user)
        owner = context&.fetch("customer_user_id", nil).to_s
        raise AccessDenied, "purchase belongs to another user" unless owner == user.fetch("id").to_s
      end

      def payment_pending?(order)
        order.dig("attributes", "status") == "payment_pending"
      end

      def executable?(order)
        attributes = order.fetch("attributes")
        return true if %w[accepted pending].include?(attributes.fetch("status"))

        attributes.fetch("status") == "failed" && attributes.dig("failure", "retryable")
      end
    end
end
