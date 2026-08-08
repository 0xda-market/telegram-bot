# frozen_string_literal: true

require_relative "telegram_mini_app"
require_relative "telegram_api"
require_relative "telegram_web_app_auth"

module ZeroXDA::Market::TelegramBot
  module RecipientPickerMiniApp
    TOKEN_PATTERN = /\A[0-9a-f]{32}\z/

    def call(environment)
      request = Rack::Request.new(environment)
      if request.post? && request.path_info == "/webapp/recipient-picker"
        document = @service.prepare_recipient_picker(init_data: init_data(request))
        return post_document(201, document)
      end

      match = request.path_info.match(%r{\A/webapp/recipient-picker/([^/]+)\z})
      if request.get? && match
        token = match[1].to_s
        raise ArgumentError, "recipient picker token is invalid" unless TOKEN_PATTERN.match?(token)

        document = @service.recipient_picker_result(init_data: init_data(request), token: token)
        return json_document(200, document)
      end

      super
    rescue TelegramWebAppAuth::Invalid => error
      json_response(401, status: "error", error: "invalid_telegram_session", message: error.message)
    rescue TelegramAPI::Error => error
      json_response(502, status: "error", error: "telegram_api_error", message: error.message)
    rescue ArgumentError => error
      json_response(422, status: "error", error: "invalid_request", message: error.message)
    end
  end

  TelegramMiniApp.prepend(RecipientPickerMiniApp)
end
