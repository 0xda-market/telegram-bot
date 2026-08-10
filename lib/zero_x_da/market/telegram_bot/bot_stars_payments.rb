# frozen_string_literal: true

require_relative "namespace"
require_relative "bot"

module ZeroXDA::Market::TelegramBot
  module BotStarsPayments
    TERMS_ACCEPT_CALLBACK_PATTERN = /\Ata:([A-Za-z0-9:_-]{1,61})\z/

    def initialize(payments: nil, payment_terms: nil, payment_support_text: nil, **options)
      @payments = payments
      @payment_terms = payment_terms
      @payment_support_text = payment_support_text.to_s.strip
      if @payments && !@payment_terms
        raise ArgumentError, "payment_terms is required when real payments are enabled"
      end
      super(**options)
    end

    private

    def supported_command?(text)
      command = parse_command(text).first
      return true if @payments && %w[/paysupport /terms].include?(command)

      super
    end

    def dispatch_command(command, message, argument)
      return payment_support(message, argument) if @payments && command == "/paysupport"
      return payment_terms(message) if @payments && command == "/terms"

      super
    end

    def handle_callback(callback)
      data = callback.fetch("data").to_s
      if @payments && (match = TERMS_ACCEPT_CALLBACK_PATTERN.match(data))
        return handle_terms_acceptance(callback, match[1])
      end

      super
    end

    # The existing q:<quote> action becomes a consent gate when real payments
    # are enabled. No order or invoice is created until the user explicitly
    # presses the versioned "I read & agree" action.
    def handle_quote_acceptance(callback, quote_id)
      return super unless @payments

      authenticate_callback_user(callback)
      locale = locale_for(callback)
      metadata = @payment_terms.metadata(locale: locale)
      reply_markup = {
        inline_keyboard: [
          [{ text: metadata.fetch("view_label"), url: metadata.fetch("url") }],
          [{ text: metadata.fetch("agree_label"), callback_data: "ta:#{quote_id}" }],
          [{ text: "Cancel", callback_data: "n" }]
        ]
      }
      replace_callback_message(
        callback,
        "#{metadata.fetch("title")}\n\n#{metadata.fetch("prompt")}",
        reply_markup: reply_markup
      )
      answer_callback(callback)
    end

    def handle_terms_acceptance(callback, quote_id)
      user = authenticate_callback_user(callback)
      locale = locale_for(callback)
      consent = @payment_terms.server_accept(
        telegram_user_id: callback.fetch("from").fetch("id"),
        locale: locale
      )
      order = @purchase_flow.accept(quote_id: quote_id, user: user)
      order = @payments.attach_invoice(
        order: order,
        telegram_user: callback.fetch("from"),
        consent: consent
      )
      screen = PurchaseMessages.order(order: order, locale: locale)
      add_invoice_button!(screen, order)
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    def payment_terms(message)
      locale = locale_for(message)
      send_message(message.fetch("chat").fetch("id"), @payment_terms.text(locale: locale))
    end

    def payment_support(message, _argument)
      text = @payment_support_text
      text = "Payment support: send your 0xda-market order ID and Telegram payment transaction ID in this chat so the payment can be reviewed. Telegram is not the seller; 0xda-market handles purchase disputes and refunds." if text.empty?
      send_message(message.fetch("chat").fetch("id"), text)
    end

    def add_invoice_button!(screen, order)
      invoice_link = order.dig("attributes", "payment", "invoice_link")
      return unless invoice_link

      rows = screen.reply_markup.fetch(:inline_keyboard)
      rows.unshift([{ text: "Pay with Telegram Stars ⭐", url: invoice_link }])
    end
  end

  Bot.prepend(BotStarsPayments)
end
