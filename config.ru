# frozen_string_literal: true

require "bundler/setup"
require "rack/common_logger"
require_relative "lib/zero_x_da/market_client_bot/bot"
require_relative "lib/zero_x_da/market_client_bot/persistent_runtime"
require_relative "lib/zero_x_da/market_client_bot/bot_identity"
require_relative "lib/zero_x_da/market_client_bot/command_menu"
require_relative "lib/zero_x_da/market_client_bot/http_app"
require_relative "lib/zero_x_da/market_client_bot/market_api"
require_relative "lib/zero_x_da/market_client_bot/telegram_api"
require_relative "lib/zero_x_da/market_client_bot/telegram_mini_app"
require_relative "lib/zero_x_da/market_client_bot/telegram_web_app_auth"
require_relative "lib/zero_x_da/market_client_bot/telegram_web_app_service"

bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN")
telegram_api = ZeroXDA::MarketClientBot::TelegramAPI.new(token: bot_token)
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
bot.extend(ZeroXDA::MarketClientBot::PersistentRuntime)
web_app_auth = ZeroXDA::MarketClientBot::TelegramWebAppAuth.new(
  bot_token: bot_token,
  max_age_seconds: Integer(ENV.fetch("TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS", "3600"))
)
web_app_service = ZeroXDA::MarketClientBot::TelegramWebAppService.new(
  market_api: market_api,
  authentication: web_app_auth
)
mini_app = ZeroXDA::MarketClientBot::TelegramMiniApp.new(
  service: web_app_service,
  root: File.expand_path("webapp", __dir__)
)

use Rack::CommonLogger, $stdout

run ZeroXDA::MarketClientBot::TelegramBotHTTPApp.new(
  bot: bot,
  webhook_secret: ENV.fetch("TELEGRAM_WEBHOOK_SECRET"),
  telegram_username: telegram_username,
  mini_app: mini_app
)
