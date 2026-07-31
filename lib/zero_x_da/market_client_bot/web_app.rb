# frozen_string_literal: true

require_relative "http_app"

module ZeroXDA
  module MarketClientBot
    # Compatibility alias for integrations that still require `web_app`. The
    # canonical runtime is TelegramBotHTTPApp; the actual Mini App lives under
    # the repository's `webapp/` browser surface.
    WebApp = TelegramBotHTTPApp unless const_defined?(:WebApp, false)
  end
end
