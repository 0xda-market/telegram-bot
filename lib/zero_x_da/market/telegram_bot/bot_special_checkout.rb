# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "bot"
require_relative "nilx_identity_api"
require_relative "special_checkout_messages"
require_relative "special_confirmation"

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
    ORDER_ARGUMENT = /\A[A-Za-z0-9_-]{1,61}\z/

    # identity: NilxIdentityAPI; link_url: where a person signs in to 0x1 and
    # connects this Telegram account (the 0x1 Mini App or site).
    Configuration = Data.define(:identity, :link_url, :confirmation_secret) do
      def initialize(identity:, link_url:, confirmation_secret:)
        raise ArgumentError, "Special confirmation secret must be at least 32 bytes" if confirmation_secret.to_s.bytesize < 32

        super
      end
    end

    def self.validate_bot!(environment:, actual_bot:, configured_bot:)
      matches = !configured_bot.to_s.empty? && actual_bot.to_s.casecmp?(configured_bot)
      test_bot = actual_bot.to_s.casecmp?("zeroxda_market_test_bot")
      isolated = (environment == "development" && test_bot) || (environment == "production" && !test_bot)
      raise ArgumentError, "Special checkout bot identity does not match its environment" unless matches && isolated
    end

    def subscription_catalog_note(locale)
      @special_checkout ? t(:subscription_seeds_note, locale: locale) : super
    end

    def initialize(special_checkout: nil, **options)
      @special_checkout = special_checkout
      super(**options)
    end

    private

    # A Mini App link selects an offer. Only the existing confirm callback can pay.
    def dispatch_command(command, message, argument)
      return super unless command == "/start" && special_checkout?(argument.to_s)
      chat = message.fetch("chat")
      return super unless chat["type"] == "private" && chat["id"] == message.dig("from", "id")

      authenticate_user(message)
      locale = locale_for(message)
      screen = special_account_screen(message, argument, locale) do |account, price, name|
        SpecialCheckoutMessages.offer(name: name, sku: argument, account: account, price: price, locale: locale)
      end
      send_message(chat.fetch("id"), screen.text, reply_markup: screen.reply_markup)
    end

    # v: and z: on a Special open the account-aware offer; x: confirms it.
    def show_subscription_offer_callback(callback, sku)
      return super unless special_checkout?(sku)
      return special_private_only(callback) unless special_private_chat?(callback)

      special_offer(callback, sku)
    end

    def handle_subscription_action_callback(callback, action, sku)
      return super unless special_checkout?(sku) && action != "y"
      return special_private_only(callback) unless special_private_chat?(callback)

      action == "x" ? special_confirm(callback, sku) : special_offer(callback, sku)
    end

    # The nonce in k: is minted when the confirmation is drawn: a double tap on
    # that button replays one order, while a later confirmation is new.
    def handle_issuer_checkout_callback(callback, action, argument)
      return super unless @special_checkout
      return special_private_only(callback) unless special_private_chat?(callback)

      case action
      when "k"
        match = SpecialConfirmation::PATTERN.match(argument)
        return super unless match && SPECIAL_SKU.match?(match[1])

        special_place(callback, match[1], argument)
      when "w" then ORDER_ARGUMENT.match?(argument) ? special_refresh(callback, argument) : super
      when "u" then ORDER_ARGUMENT.match?(argument) ? special_cancel(callback, argument) : super
      end
    end

    def special_private_chat?(callback)
      callback.dig("message", "chat", "type") == "private" &&
        callback.dig("message", "chat", "id") == callback.dig("from", "id")
    end

    def special_private_only(callback)
      answer_callback(callback, text: t(:access_denied, locale: locale_for(callback)))
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
      screen = special_account_screen(callback, sku, locale) do |account, price, name, price_id|
        if special_buyable?(account, price)
          SpecialCheckoutMessages.confirm(name: name, sku: sku, account: account, price: price, locale: locale,
                                          token: SpecialConfirmation.issue(secret: @special_checkout.confirmation_secret,
                                            callback: callback, sku: sku, bond: account.pub_dress,
                                            price_id: price_id, amount: price, now: @clock.call))
        else
          SpecialCheckoutMessages.offer(name: name, sku: sku, account: account, price: price, locale: locale)
        end
      end
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    # Confirm the same Telegram sender and Bond, then submit the signed terms.
    # Market checks current price for new orders and replays an existing order;
    # Identity checks the wallet and Special under its lock before any debit.
    def special_place(callback, sku, token)
      locale = locale_for(callback)
      user = authenticate_callback_user(callback)
      order = nil
      screen = special_account_screen(callback, sku, locale) do |account, price, name|
        terms = SpecialConfirmation.verify(token: token, secret: @special_checkout.confirmation_secret,
                                           callback: callback, bond: account.pub_dress, now: @clock.call)
        next SpecialCheckoutMessages.offer(name: name, sku: sku, account: account, price: price, locale: locale) unless terms

        # Send the original terms even if the wallet/catalog changed: Market
        # replays the same order first, or rejects stale terms before creating one.
        order = @market_api.create_issuer_order(
          customer: special_customer(user, callback), sku: sku, denomination: DENOMINATION,
          idempotency_key: "tg.#{callback.fetch("from").fetch("id")}.#{token.split(":").last}",
          expected_price_id: terms.fetch(:price_id), expected_amount_minor: terms.fetch(:amount),
          expected_recipient_subject: account.pub_dress
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

      price, price_id = special_price(sku, locale)
      yield account, price, name, price_id
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
      price_id = entry&.dig("attributes", "price_id")
      return unless amount.is_a?(Integer) && amount.positive? && price_id.is_a?(Integer) && price_id.positive?

      [amount, price_id]
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

  end

  Bot.prepend(BotSpecialCheckout)
end
