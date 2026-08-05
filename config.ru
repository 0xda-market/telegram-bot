# frozen_string_literal: true

require "bundler/setup"
require "rack/common_logger"
require_relative "lib/zero_x_da/market/telegram_bot/bot"
require_relative "lib/zero_x_da/market/telegram_bot/persistent_runtime"
require_relative "lib/zero_x_da/market/telegram_bot/bot_identity"
require_relative "lib/zero_x_da/market/telegram_bot/command_menu"
require_relative "lib/zero_x_da/market/telegram_bot/mini_app_entry_point"
require_relative "lib/zero_x_da/market/telegram_bot/http_app"
require_relative "lib/zero_x_da/market/telegram_bot/market_api"
require_relative "lib/zero_x_da/market/telegram_bot/telegram_api"
require_relative "lib/zero_x_da/market/telegram_bot/telegram_mini_app"
require_relative "lib/zero_x_da/market/telegram_bot/encoded_resource_identifiers"
require_relative "lib/zero_x_da/market/telegram_bot/telegram_web_app_auth"
require_relative "lib/zero_x_da/market/telegram_bot/telegram_web_app_service"
require_relative "lib/zero_x_da/market/telegram_bot/broker_order_notifier"
require_relative "lib/zero_x_da/market/telegram_bot/broker_order_web_app_service"
require_relative "lib/zero_x_da/market/telegram_bot/broker_order_mini_app"
require_relative "lib/zero_x_da/market/telegram_bot/runtime_event_notifier"
require_relative "lib/zero_x_da/market/telegram_bot/runtime_event_mini_app"

bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN")
public_url = ENV.fetch("PUBLIC_URL").delete_suffix("/")
deploy_environment = ENV.fetch("DEPLOY_ENV", "development")
telegram_api = ZeroXDA::Market::TelegramBot::TelegramAPI.new(token: bot_token)
telegram_username = ZeroXDA::Market::TelegramBot::TelegramBotIdentity.resolve(
  configured_username: ENV["TELEGRAM_BOT_USERNAME"],
  telegram_api: telegram_api
)
market_api = ZeroXDA::Market::TelegramBot::MarketAPI.new(
  base_url: ENV.fetch("MARKET_API_URL", "https://zeroxda-market.onrender.com"),
  token: ENV.fetch("MARKET_API_TOKEN")
)
bot = ZeroXDA::Market::TelegramBot::Bot.new(
  market_api: market_api,
  telegram_api: telegram_api,
  web_app_url: "#{public_url}/webapp/"
)
bot.extend(ZeroXDA::Market::TelegramBot::PersistentRuntime)
web_app_auth = ZeroXDA::Market::TelegramBot::TelegramWebAppAuth.new(
  bot_token: bot_token,
  max_age_seconds: Integer(ENV.fetch("TELEGRAM_WEBAPP_AUTH_MAX_AGE_SECONDS", "3600"))
)
broker_order_notifier = ZeroXDA::Market::TelegramBot::BrokerOrderNotifier.new(
  market_api: market_api,
  telegram_api: telegram_api
)
web_app_service = ZeroXDA::Market::TelegramBot::TelegramWebAppService.new(
  market_api: market_api,
  authentication: web_app_auth,
  environment: deploy_environment,
  broker_order_notifier: broker_order_notifier
)
mini_app = ZeroXDA::Market::TelegramBot::TelegramMiniApp.new(
  service: web_app_service,
  root: File.expand_path("webapp", __dir__)
)
runtime_event_notifier = ZeroXDA::Market::TelegramBot::RuntimeEventNotifier.new(
  market_api: market_api,
  telegram_api: telegram_api
)
mini_app = ZeroXDA::Market::TelegramBot::RuntimeEventMiniApp.new(
  app: mini_app,
  authentication: web_app_auth,
  notifier: runtime_event_notifier,
  environment: deploy_environment
)

use Rack::CommonLogger, $stdout

run ZeroXDA::Market::TelegramBot::TelegramBotHTTPApp.new(
  bot: bot,
  webhook_secret: ENV.fetch("TELEGRAM_WEBHOOK_SECRET"),
  telegram_username: telegram_username,
  mini_app: mini_app
)
