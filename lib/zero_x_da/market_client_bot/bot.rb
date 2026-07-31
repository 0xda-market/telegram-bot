# frozen_string_literal: true

require "time"
require_relative "market_api"
require_relative "telegram_api"
require_relative "price_messages"
require_relative "locale"
require_relative "i18n"
require_relative "catalog_menu"
require_relative "purchase_flow"
require_relative "purchase_messages"

module ZeroXDA
  module MarketClientBot
    class Bot
      include I18n::Helpers

      MESSAGE_LIMIT = 3_800
      SERVER_START_NOTICE_DELAY = 3
      STATUS_MESSAGE_TTL = 3
      SKU_PATTERN = /([a-z0-9][a-z0-9_-]{0,59})/
      RESOURCE_ID_PATTERN = /([A-Za-z0-9:_-]{1,61})/
      BUY_CALLBACK_PATTERN = /\Ab:#{SKU_PATTERN}\z/
      LEGACY_BUY_CALLBACK_PATTERN = /\Abuy_#{SKU_PATTERN}\z/
      APPLY_PRICE_CALLBACK_PATTERN = /\Ap:#{SKU_PATTERN}\z/
      LEGACY_APPLY_PRICE_CALLBACK_PATTERN = /\Aapplyprice_#{SKU_PATTERN}\z/
      CATEGORY_CALLBACK_PATTERN = /\Ac:([bp]):#{SKU_PATTERN}\z/
      HOME_CALLBACK_PATTERN = /\Ah:([bp])\z/
      QUOTE_CALLBACK_PATTERN = /\Aq:#{RESOURCE_ID_PATTERN}\z/
      ORDER_CALLBACK_PATTERN = /\Ao:#{RESOURCE_ID_PATTERN}\z/
      PRICE_REPLY_PATTERN = /\[price:#{SKU_PATTERN}\]/
      PRICE_AMOUNT_PATTERN = /\A\d+(?:\.\d{1,6})?\z/
      CURRENCY_INPUT_PATTERN = /\A[A-Za-z][A-Za-z0-9]{2,9}\z/
      SUPPORTED_COMMANDS = %w[
        /start /status /buy /servers /users /set_admin /apply_prices /apply_price /rates /set_rate
      ].freeze

      def initialize(
        market_api:,
        telegram_api:,
        clock: -> { Time.now.utc },
        server_start_notice_delay: SERVER_START_NOTICE_DELAY,
        status_message_ttl: STATUS_MESSAGE_TTL
      )
        @market_api = market_api
        @telegram_api = telegram_api
        @clock = clock
        @server_start_notice_delay = server_start_notice_delay
        @status_message_ttl = status_message_ttl
        @catalog_menu = CatalogMenu.new
        @purchase_flow = PurchaseFlow.new(market_api: market_api)
      end

      def handle(update)
        message = update["message"]
        callback = update["callback_query"]
        return handle_callback(callback) if callback
        return unless message

        command, argument = parse_command(message["text"])
        if command
          with_server_start_notice(message) { dispatch_command(command, message, argument) }
        elsif (sku = price_reply_sku(message))
          continue_price_reply(message, sku)
        elsif message["text"].to_s.strip.match?(PRICE_AMOUNT_PATTERN)
          send_message(
            message.fetch("chat").fetch("id"),
            PriceMessages.reply_missing(locale: locale_for(message))
          )
        end
      rescue KeyError, ArgumentError, MarketAPI::Error => error
        notify_failure(message || callback&.fetch("message", nil), error)
      end

      private

      def dispatch_command(command, message, argument)
        case command
        when "/start" then authenticate(message)
        when "/status" then show_status(message)
        when "/buy" then show_products(message)
        when "/servers" then show_servers(message)
        when "/users" then show_active_users(message)
        when "/set_admin" then set_admin(message, argument)
        when "/apply_prices" then start_price_application(message)
        when "/apply_price" then apply_single_price(message, argument)
        when "/rates" then show_currency_prices(message)
        when "/set_rate" then set_currency_price(message, argument)
        end
      end

      def with_server_start_notice(message)
        return yield unless supported_command?(message["text"])

        chat_id = message.fetch("chat").fetch("id")
        locale = locale_for(message)
        completed = false
        lock = Mutex.new
        notifier = Thread.new do
          sleep @server_start_notice_delay
          send_message(chat_id, t(:server_starting, locale: locale)) unless lock.synchronize { completed }
        rescue TelegramAPI::Error => error
          warn "server start notice failed: #{error.message}"
        end
        notifier.report_on_exception = false
        yield
      ensure
        if lock
          lock.synchronize { completed = true }
          notifier&.kill
        end
      end

      def supported_command?(text)
        SUPPORTED_COMMANDS.include?(parse_command(text).first)
      end

      def parse_command(text)
        match = text.to_s.match(%r{\A(/\w+)(?:@\w+)?(?:\s+(.+)|\z)})
        [match&.[](1)&.downcase, match&.[](2)&.strip]
      end

      def authenticate(message)
        chat = message.fetch("chat")
        user = @market_api.authenticate_telegram(user: message.fetch("from"), chat: chat)
        chat_id = chat.fetch("id")
        sync_commands(chat_id, user)
        send_status_message(chat_id, user)
      end

      def show_status(message)
        chat_id = message.fetch("chat").fetch("id")
        user = authenticate_user(message)
        sync_commands(chat_id, user)
        send_status_message(chat_id, user)
      end

      def show_products(message)
        chat_id = message.fetch("chat").fetch("id")
        user = authenticate_user(message)
        sync_commands(chat_id, user)
        locale = locale_for(message)
        screen = @catalog_menu.root(
          products: catalog_products(mode: "b", locale: locale),
          mode: "b",
          locale: locale
        )
        send_message(chat_id, t(:choose_product_to_buy), reply_markup: screen.reply_markup)
      end

      def handle_callback(callback)
        data = callback.fetch("data").to_s
        case data
        when "n"
          answer_callback(callback)
        when HOME_CALLBACK_PATTERN
          show_catalog_root_callback(callback, Regexp.last_match(1))
        when CATEGORY_CALLBACK_PATTERN
          show_catalog_category_callback(callback, Regexp.last_match(1), Regexp.last_match(2))
        when BUY_CALLBACK_PATTERN, LEGACY_BUY_CALLBACK_PATTERN
          handle_buy_callback(callback, Regexp.last_match(1))
        when APPLY_PRICE_CALLBACK_PATTERN, LEGACY_APPLY_PRICE_CALLBACK_PATTERN
          handle_apply_price_callback(callback, Regexp.last_match(1))
        when QUOTE_CALLBACK_PATTERN
          handle_quote_acceptance(callback, Regexp.last_match(1))
        when ORDER_CALLBACK_PATTERN
          handle_order_refresh(callback, Regexp.last_match(1))
        else
          answer_callback(callback)
        end
      rescue PurchaseFlow::AccessDenied
        answer_callback(callback, text: t(:access_denied, locale: locale_for(callback)))
      rescue PurchaseFlow::UnpricedProduct
        screen = PurchaseMessages.unpriced(locale: locale_for(callback))
        replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
        answer_callback(callback)
      rescue MarketAPI::Error => error
        return handle_expired_quote(callback) if error.code == "quote_expired"

        raise
      end

      def show_catalog_root_callback(callback, mode)
        locale = locale_for(callback)
        ensure_price_admin!(callback) if mode == "p"
        screen = @catalog_menu.root(
          products: catalog_products(mode: mode, locale: locale),
          mode: mode,
          locale: locale
        )
        replace_callback_message(callback, catalog_root_title(mode, locale), reply_markup: screen.reply_markup)
        answer_callback(callback)
      end

      def show_catalog_category_callback(callback, mode, anchor_sku)
        locale = locale_for(callback)
        ensure_price_admin!(callback) if mode == "p"
        screen = @catalog_menu.category(
          products: catalog_products(mode: mode, locale: locale),
          mode: mode,
          anchor_sku: anchor_sku,
          locale: locale
        )
        text = "#{catalog_root_title(mode, locale)}\n\n#{screen.title}"
        replace_callback_message(callback, text, reply_markup: screen.reply_markup)
        answer_callback(callback)
      end

      def handle_buy_callback(callback, sku)
        message = callback.fetch("message")
        locale = locale_for(callback)
        user = authenticate_callback_user(callback)
        sync_commands(message.fetch("chat").fetch("id"), user)
        product = find_product_by_sku(sku, locale: locale, mode: "b")
        raise ArgumentError, t(:product_unavailable, locale: locale) unless product

        _intent, quote = @purchase_flow.quote(
          product: product,
          user: user,
          telegram_user: callback.fetch("from"),
          chat: message.fetch("chat"),
          locale: locale
        )
        screen = PurchaseMessages.quote(product: product, quote: quote, locale: locale)
        replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
        answer_callback(callback, text: t(:selected_product, locale: locale, name: product.dig("attributes", "name")))
      end

      def handle_quote_acceptance(callback, quote_id)
        user = authenticate_callback_user(callback)
        order = @purchase_flow.accept(quote_id: quote_id, user: user)
        screen = PurchaseMessages.order(order: order, locale: locale_for(callback))
        replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
        answer_callback(callback)
      end

      def handle_order_refresh(callback, order_id)
        user = authenticate_callback_user(callback)
        order = @purchase_flow.refresh(order_id: order_id, user: user)
        screen = PurchaseMessages.order(order: order, locale: locale_for(callback))
        replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
        answer_callback(callback)
      end

      def handle_expired_quote(callback)
        screen = PurchaseMessages.quote_expired(locale: locale_for(callback))
        replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
        answer_callback(callback)
      end

      def handle_apply_price_callback(callback, sku)
        message = callback.fetch("message")
        locale = locale_for(callback)
        user = authenticate_callback_user(callback)
        sync_commands(message.fetch("chat").fetch("id"), user)
        raise PurchaseFlow::AccessDenied unless admin?(user)

        product = find_product_by_sku(sku, locale: locale, mode: "p")
        raise ArgumentError, t(:product_unavailable, locale: locale) unless product

        request_price_amount(
          chat_id: message.fetch("chat").fetch("id"),
          product: product,
          locale: locale
        )
        answer_callback(callback, text: t(:selected_product, locale: locale, name: product.dig("attributes", "name")))
      end

      def ensure_price_admin!(callback)
        user = authenticate_callback_user(callback)
        sync_commands(callback.dig("message", "chat", "id"), user)
        raise PurchaseFlow::AccessDenied unless admin?(user)
      end

      def catalog_products(mode:, locale:)
        products = @market_api.products(locale: locale, currency: mode == "b" ? "USDT" : nil)
        return products if mode == "b"

        (products + @market_api.currencies(locale: locale)).uniq { |product| product.fetch("id") }
      end

      def find_product_by_sku(sku, locale:, mode:)
        catalog_products(mode: mode, locale: locale).find { |entry| entry.fetch("id") == sku }
      end

      def catalog_root_title(mode, locale)
        mode == "b" ? t(:choose_product_to_buy, locale: locale) : PriceMessages.choose_product(locale: locale)
      end

      def apply_single_price(message, argument)
        chat_id = message.fetch("chat").fetch("id")
        user = authenticate_user(message)
        sync_commands(chat_id, user)
        return send_message(chat_id, t(:access_denied)) unless admin?(user)

        locale = locale_for(message)
        parts = argument.to_s.split(/\s+/)
        return request_product_selection(chat_id: chat_id, locale: locale) if parts.empty?

        amount = parts.last if parts.length >= 2 && parts.last.match?(PRICE_AMOUNT_PATTERN)
        reference = (amount ? parts[0..-2] : parts).join(" ")
        product = resolve_product(reference, locale: locale)

        if product && amount
          perform_price_application(
            chat_id: chat_id,
            actor_user_id: user.fetch("id"),
            sku: product.fetch("id"),
            name: product.dig("attributes", "name"),
            amount: amount,
            locale: locale
          )
        elsif product
          request_price_amount(chat_id: chat_id, product: product, locale: locale)
        elsif amount.nil? && parts.length >= 2 &&
              (product = resolve_product(parts[0..-2].join(" "), locale: locale))
          send_message(chat_id, PriceMessages.invalid_amount(locale: locale))
          request_price_amount(chat_id: chat_id, product: product, locale: locale)
        else
          send_message(chat_id, PriceMessages.product_not_found(reference, locale: locale))
          request_product_selection(chat_id: chat_id, locale: locale)
        end
      end

      # `/set_rate` remains a Telegram compatibility command. It resolves one
      # registered core currency and writes through the same generic price API
      # used by every other priced catalog item.
      def set_currency_price(message, argument)
        chat_id = message.fetch("chat").fetch("id")
        user = authenticate_user(message)
        sync_commands(chat_id, user)
        return send_message(chat_id, t(:access_denied)) unless admin?(user)

        locale = locale_for(message)
        code, value = argument.to_s.split(/\s+/, 2)
        value = value&.strip
        unless code&.match?(CURRENCY_INPUT_PATTERN) && value&.match?(PRICE_AMOUNT_PATTERN)
          return send_message(chat_id, t(:currency_price_format, locale: locale))
        end

        currency = resolve_currency(code, locale: locale)
        unless currency
          return send_message(
            chat_id,
            t(:currency_not_found, locale: locale, currency: code.upcase)
          )
        end

        applied = @market_api.apply_prices(
          actor_user_id: user.fetch("id"),
          prices: [{ sku: currency.fetch("id"), amount_usdt: value }]
        )
        price = applied.first
        currency_code = currency.dig("attributes", "code") || currency.fetch("id").upcase
        send_message(
          chat_id,
          t(
            :currency_price_applied,
            locale: locale,
            currency: currency_code,
            amount: price.dig("attributes", "amount_usdt")
          )
        )
      end

      def resolve_currency(reference, locale:)
        code = reference.to_s.strip
        @market_api.currencies(locale: locale).find do |currency|
          currency.fetch("id").casecmp?(code) ||
            currency.dig("attributes", "code").to_s.casecmp?(code)
        end
      end

      def request_product_selection(chat_id:, locale:)
        screen = @catalog_menu.root(
          products: catalog_products(mode: "p", locale: locale),
          mode: "p",
          locale: locale
        )
        send_message(chat_id, PriceMessages.choose_product(locale: locale), reply_markup: screen.reply_markup)
      end

      def request_price_amount(chat_id:, product:, locale:)
        sku = product.fetch("id")
        text = "#{PriceMessages.enter_amount(product.dig("attributes", "name"), locale: locale)}\n\n[price:#{sku}]"
        send_message(
          chat_id,
          text,
          reply_markup: {
            force_reply: true,
            selective: true,
            input_field_placeholder: "7.45"
          }
        )
      end

      def price_reply_sku(message)
        reply_text = message.dig("reply_to_message", "text").to_s
        PRICE_REPLY_PATTERN.match(reply_text)&.[](1)
      end

      def continue_price_reply(message, sku)
        chat_id = message.fetch("chat").fetch("id")
        user = authenticate_user(message)
        sync_commands(chat_id, user)
        return send_message(chat_id, t(:access_denied)) unless admin?(user)

        locale = locale_for(message)
        product = find_product_by_sku(sku, locale: locale, mode: "p")
        raise ArgumentError, t(:product_unavailable, locale: locale) unless product

        amount = message["text"].to_s.strip
        unless amount.match?(PRICE_AMOUNT_PATTERN)
          send_message(chat_id, PriceMessages.invalid_amount(locale: locale))
          return request_price_amount(chat_id: chat_id, product: product, locale: locale)
        end

        perform_price_application(
          chat_id: chat_id,
          actor_user_id: user.fetch("id"),
          sku: sku,
          name: product.dig("attributes", "name"),
          amount: amount,
          locale: locale
        )
      end

      def perform_price_application(chat_id:, actor_user_id:, sku:, name:, amount:, locale:)
        applied = @market_api.apply_prices(
          actor_user_id: actor_user_id,
          prices: [{ sku: sku, amount_usdt: amount }]
        )
        price = applied.first
        send_message(
          chat_id,
          t(
            :price_applied,
            locale: locale,
            name: name,
            sku: sku,
            amount: price.dig("attributes", "amount_usdt")
          )
        )
      end

      def resolve_product(reference, locale:)
        products = catalog_products(mode: "p", locale: locale)
        normalized = reference.to_s.downcase.strip
        products.find { |product| product.fetch("id") == normalized } ||
          products.find { |product| product.dig("attributes", "position").to_s == normalized } ||
          fuzzy_product_match(products, normalized)
      end

      def fuzzy_product_match(products, reference)
        tokens = reference.split(/[^a-z0-9]+/).reject(&:empty?)
        return nil if tokens.empty?

        matches = products.select do |product|
          haystack = [
            product.fetch("id"),
            product.dig("attributes", "short_name"),
            product.dig("attributes", "name"),
            product.dig("attributes", "button_label")
          ].compact.join(" ").downcase
          words = haystack.split(/[^[:alnum:]]+/).reject(&:empty?)
          tokens.all? do |token|
            haystack.include?(token) || words.any? { |word| word.start_with?(token) }
          end
        end
        matches.length == 1 ? matches.first : nil
      end

      def authenticate_user(message)
        @market_api.authenticate_telegram(user: message.fetch("from"), chat: message.fetch("chat"))
      end

      def authenticate_callback_user(callback)
        @market_api.authenticate_telegram(
          user: callback.fetch("from"),
          chat: callback.fetch("message").fetch("chat")
        )
      end

      def locale_for(update)
        Locale.resolve(update.fetch("from", {})["language_code"])
      end

      def admin?(user)
        user.dig("attributes", "role") == "admin"
      end

      def user_status_message(user)
        role = client_role(user)
        status = user.dig("attributes", "status")
        indicator = status == "active" ? "✅" : "❌"
        <<~TEXT.strip
          #{t(:authorization_success)}
          role: #{role}
          status: #{status} #{indicator}
        TEXT
      end

      def send_status_message(chat_id, user)
        message = send_message(chat_id, user_status_message(user))
        schedule_message_deletion(chat_id, message)
      end

      def schedule_message_deletion(chat_id, message)
        message_id = message&.fetch("message_id", nil)
        return unless message_id

        delete = -> { @telegram_api.delete_message(chat_id: chat_id, message_id: message_id) }
        return delete.call if @status_message_ttl.zero?

        Thread.new do
          sleep @status_message_ttl
          delete.call
        rescue TelegramAPI::Error => error
          warn "status message deletion failed: #{error.message}"
        end.tap { |thread| thread.report_on_exception = false }
      end

      def client_role(user)
        admin?(user) ? "admin" : "client"
      end

      def answer_callback(callback, text: nil)
        @telegram_api.answer_callback_query(callback_query_id: callback.fetch("id"), text: text)
      end

      def replace_callback_message(callback, text, reply_markup: nil)
        message = callback.fetch("message")
        chat_id = message.fetch("chat").fetch("id")
        message_id = message["message_id"]
        return send_message(chat_id, text, reply_markup: reply_markup) unless message_id

        @telegram_api.edit_message_text(
          chat_id: chat_id,
          message_id: message_id,
          text: text,
          reply_markup: reply_markup
        )
      end

      def send_message(chat_id, text, reply_markup: nil)
        @telegram_api.send_message(chat_id: chat_id, text: text, reply_markup: reply_markup)
      end

      def notify_failure(message, error)
        chat_id = message&.dig("chat", "id")
        return unless chat_id

        send_message(chat_id, t(:command_failed))
        warn "command failed: #{error.class}: #{error.message}"
      rescue TelegramAPI::Error
        nil
      end
    end
  end
end

require_relative "command_menu"
