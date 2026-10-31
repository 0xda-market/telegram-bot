# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "bot"
require_relative "nilx_identity_api"
require_relative "special_checkout_messages"

module ZeroXDA::Market::TelegramBot
  # Buying 0x1 Special with seeds from the chat.
  #
  # 1. The offer asks 0x1 Identity about the Telegram account that pressed the
  #    button: is it connected to a Bond, what is the wallet, does the Bond
  #    already hold Special? Unconnected accounts are sent to sign in to 0x1,
  #    and told when their Bond already holds another Telegram account.
  # 2. Buy is offered only while Identity opens a Special purchase for the
  #    Bond and the wallet covers Market's current seeds price.
  # 3. Confirm places a Market issuer order, signed as this verified customer
  #    and keyed to this message, so a double tap places one order. Identity's
  #    worker debits and grants it; the bot only shows Market's order status.
  #    "Paid" is shown only for a fulfilled order.
  #
  # Without `special_checkout:` the Special screens stay preview-only.
  module BotSpecialCheckout
    SPECIAL_SKU = /\A0x1_special_(?:1|3|6|12)m\z/
    DENOMINATION = "seeds"
    CONFIRM_ARGUMENT = /\A([a-z0-9][a-z0-9_-]{0,59}):([a-z0-9]{1,12})\z/
    ORDER_ARGUMENT = /\A[A-Za-z0-9_-]{1,61}\z/

    # identity: NilxIdentityAPI; link_url: where a person signs in to 0x1 and
    # connects this Telegram account (the 0x1 Mini App or site).
    Configuration = Data.define(:identity, :link_url)

    def initialize(special_checkout: nil, **options)
      @special_checkout = special_checkout
      super(**options)
    end

    private

    # v: and z: on a Special open the account-aware offer; x: confirms it.
    def show_subscription_offer_callback(callback, sku)
      return super unless special_checkout?(sku)

      special_offer(callback, sku)
    end

    def handle_subscription_action_callback(callback, action, sku)
      return super unless special_checkout?(sku) && action != "y"

      action == "x" ? special_confirm(callback, sku) : special_offer(callback, sku)
    end

    # The nonce in k: is minted when the confirmation is drawn: a double tap on
    # that button replays one order, while a later confirmation is new.
    def handle_issuer_checkout_callback(callback, action, argument)
      return super unless @special_checkout

      case action
      when "k"
        match = CONFIRM_ARGUMENT.match(argument)
        return super unless match && SPECIAL_SKU.match?(match[1])

        special_place(callback, match[1], match[2])
      when "w" then ORDER_ARGUMENT.match?(argument) ? special_refresh(callback, argument) : super
      when "u" then ORDER_ARGUMENT.match?(argument) ? special_cancel(callback, argument) : super
      end
    end

    def special_checkout?(sku)
      !@special_checkout.nil? && SPECIAL_SKU.match?(sku)
    end

    def special_offer(callback, sku)
      locale = locale_for(callback)
      authenticate_callback_user(callback)
      screen = special_account_screen(callback, sku, locale) do |account, price, name|
        SpecialCheckoutMessages.offer(name: name, sku: sku, account: account, price: price, locale: locale)
      end
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    def special_confirm(callback, sku)
      locale = locale_for(callback)
      authenticate_callback_user(callback)
      screen = special_account_screen(callback, sku, locale) do |account, price, name|
        if special_buyable?(account, price)
          SpecialCheckoutMessages.confirm(name: name, sku: sku, account: account, price: price, locale: locale,
                                          nonce: special_nonce)
        else
          SpecialCheckoutMessages.offer(name: name, sku: sku, account: account, price: price, locale: locale)
        end
      end
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    # The checks are repeated right before the order: the wallet or Special
    # may have changed since the offer was drawn. Identity checks them again
    # under the wallet lock before any debit.
    def special_place(callback, sku, nonce)
      locale = locale_for(callback)
      user = authenticate_callback_user(callback)
      order = nil
      screen = special_account_screen(callback, sku, locale) do |account, price, name|
        next SpecialCheckoutMessages.offer(name: name, sku: sku, account: account, price: price, locale: locale) \
          unless special_buyable?(account, price)

        order = @market_api.create_issuer_order(
          customer: special_customer(user, callback), sku: sku, denomination: DENOMINATION,
          idempotency_key: "tg.#{callback.fetch("from").fetch("id")}.#{nonce}.#{sku}"
        )
        SpecialCheckoutMessages.order(order: order, name: name, locale: locale)
      end
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    rescue MarketAPI::Error => error
      raise if error.code == "quote_expired"

      warn "Special order was not placed: #{error.code}"
      special_offer(callback, sku)
    end

    def special_refresh(callback, order_id)
      locale = locale_for(callback)
      user = authenticate_callback_user(callback)
      order = @market_api.issuer_order(order_id, customer: special_customer(user, callback))
      special_show_order(callback, order, locale)
    end

    def special_cancel(callback, order_id)
      locale = locale_for(callback)
      user = authenticate_callback_user(callback)
      customer = special_customer(user, callback)
      order = begin
        @market_api.cancel_issuer_order(order_id, customer: customer)
      rescue MarketAPI::Error
        # Already claimed by 0x1: it can no longer be cancelled; show it as it is.
        @market_api.issuer_order(order_id, customer: customer)
      end
      special_show_order(callback, order, locale)
    end

    def special_show_order(callback, order, locale)
      sku = order.dig("attributes", "sku").to_s
      screen = SpecialCheckoutMessages.order(order: order, name: special_name(sku, locale), locale: locale)
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    def special_account_screen(callback, sku, locale)
      account = @special_checkout.identity.telegram_account(callback.fetch("from").fetch("id"))
      name = special_name(sku, locale)
      unless account.linked?
        return SpecialCheckoutMessages.sign_in(name: name, sku: sku, account: account,
                                               link_url: @special_checkout.link_url, locale: locale)
      end

      yield account, special_price(sku, locale), name
    rescue NilxIdentityAPI::Error => error
      # An unreachable Identity is never "not connected".
      warn "0x1 Identity unavailable: #{error.message}"
      SpecialCheckoutMessages.unavailable(sku: sku, locale: locale)
    end

    def special_buyable?(account, price)
      account.purchase_open && !price.nil? && account.seeds >= price
    end

    # Market's current seeds price for the SKU, or nil when it is not on sale.
    def special_price(sku, locale)
      entry = @market_api.denomination_prices(DENOMINATION, locale: locale).find { |item| item["id"] == sku }
      amount = entry&.dig("attributes", "amount_minor")
      amount.is_a?(Integer) && amount.positive? ? amount : nil
    rescue MarketAPI::Error
      nil
    end

    def special_name(sku, locale)
      product = @market_api.products(locale: locale, currency: "USDT", preview_0x1: true)
                           .find { |item| item["id"] == sku }
      product&.dig("attributes", "name") || sku
    rescue MarketAPI::Error
      sku
    end

    def special_customer(user, callback)
      { user_id: user.fetch("id"), telegram_user_id: callback.fetch("from").fetch("id") }
    end

    def special_nonce
      (@clock.call.to_r * 1000).to_i.to_s(36)
    end
  end

  Bot.prepend(BotSpecialCheckout)
end
