# frozen_string_literal: true

require "bundler/setup"
require "rack/common_logger"
require_relative "lib/zero_x_da/market_client_bot/bot"
require_relative "lib/zero_x_da/market_client_bot/bot_identity"
require_relative "lib/zero_x_da/market_client_bot/command_menu"
require_relative "lib/zero_x_da/market_client_bot/http_app"
require_relative "lib/zero_x_da/market_client_bot/market_api"
require_relative "lib/zero_x_da/market_client_bot/telegram_api"

telegram_api = ZeroXDA::MarketClientBot::TelegramAPI.new(
  token: ENV.fetch("TELEGRAM_BOT_TOKEN")
)
telegram_username = ZeroXDA::MarketClientBot::TelegramBotIdentity.resolve(
  configured_username: ENV["TELEGRAM_BOT_USERNAME"],
  telegram_api: telegram_api
)
market_api = ZeroXDA::MarketClientBot::MarketAPI.new(
  base_url: ENV.fetch("MARKET_API_URL", "https://zeroxda-market.onrender.com"),
  token: ENV.fetch("MARKET_API_TOKEN")
)
bot = ZeroXDA::MarketClientBot::Bot.new(
  market_api: market_api,
  telegram_api: telegram_api
)

use Rack::CommonLogger, $stdout

run ZeroXDA::MarketClientBot::HTTPApp.new(
  bot: bot,
  webhook_secret: ENV.fetch("TELEGRAM_WEBHOOK_SECRET"),
  telegram_username: telegram_username
)
