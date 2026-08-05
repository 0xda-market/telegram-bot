# frozen_string_literal: true

require "uri"
require_relative "telegram_mini_app"

module ZeroXDA::Market::TelegramBot
  module EncodedResourceIdentifiers
    private

    def resource_id(value)
      super(URI::DEFAULT_PARSER.unescape(value.to_s))
    rescue ArgumentError
      raise ArgumentError, "resource id is invalid"
    end
  end

  TelegramMiniApp.prepend(EncodedResourceIdentifiers)
end
