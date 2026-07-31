# frozen_string_literal: true

require_relative "http_app"

module ZeroXDA
  module MarketClientBot
    # Compatibility alias for integrations that still require `web_app`.
    # New code must construct HTTPApp directly; a future Telegram Mini App is a
    # separate surface with its own request-signature contract.
    WebApp = HTTPApp unless const_defined?(:WebApp, false)
  end
end
