# frozen_string_literal: true

require_relative "namespace"
require_relative "bot"

module ZeroXDA::Market::TelegramBot
  module BotStarsPayments
    def initialize(payments: nil, payment_support_text: nil, **options)
      @payments = payments
      @payment_support_text = payment_support_text.to_s.strip
      super(**options)
    end

    private

    def supported_command?(text)
      parse_command(text).first == "/paysupport" || super
    end

    def dispatch_command(command, message, argument)
      return payment_support(message, argument) if command == "/paysupport"

      super
    end

    def handle_quote_acceptance(callback, quote_id)
      user = authenticate_callback_user(callback)
      order = @purchase_flow.accept(quote_id: quote_id, user: user)
      order = @payments.attach_invoice(order: order, telegram_user: callback.fetch("from")) if @payments
      screen = PurchaseMessages.order(order: order, locale: locale_for(callback))
      add_invoice_button!(screen, order)
      replace_callback_message(callback, screen.text, reply_markup: screen.reply_markup)
      answer_callback(callback)
    end

    def payment_support(message, _argument)
      text = @payment_support_text
      text = "Payment support: send your 0xda-market order ID and Telegram payment transaction ID in this chat so the payment can be reviewed." if text.empty?
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
