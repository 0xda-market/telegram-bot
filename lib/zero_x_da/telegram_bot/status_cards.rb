# frozen_string_literal: true

require_relative "i18n"

module ZeroXDA
  module TelegramBot
    module StatusCards
      ACCOUNT_CALLBACK = "s:a"
      SERVERS_CALLBACK = "s:s"

      private

      def handle_callback(callback)
        case callback.fetch("data").to_s
        when ACCOUNT_CALLBACK
          refresh_account_status(callback)
        when SERVERS_CALLBACK
          refresh_servers(callback)
        else
          super
        end
      rescue PurchaseFlow::AccessDenied
        answer_callback(callback, text: t(:access_denied, locale: locale_for(callback)))
      end

      def refresh_account_status(callback)
        locale = locale_for(callback)
        user = authenticate_callback_user(callback)
        chat_id = callback.fetch("message").fetch("chat").fetch("id")
        sync_commands(chat_id, user)
        replace_callback_message(
          callback,
          user_status_message(user),
          reply_markup: status_card_keyboard(ACCOUNT_CALLBACK, locale: locale)
        )
        answer_callback(callback)
      end

      def send_status_message(chat_id, user)
        send_message(
          chat_id,
          user_status_message(user),
          reply_markup: status_card_keyboard(ACCOUNT_CALLBACK, locale: current_locale)
        )
      end

      def status_card_keyboard(callback_data, locale:)
        {
          inline_keyboard: [
            [
              {
                text: t(:refresh_status, locale: locale),
                callback_data: callback_data
              }
            ]
          ]
        }
      end
    end

    Bot.prepend(StatusCards)
  end
end
