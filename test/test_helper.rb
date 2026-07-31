$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cgi"
require "minitest/autorun"

class FakeMarketAPI
  ACTOR_USER_ID = "12345678-1234-4000-8000-123456789012"

  attr_reader :requests,
              :health_requests,
              :product_requests,
              :product_locales,
              :price_proposal_requests,
              :applied_prices,
              :fx_rate_requests,
              :applied_fx_rates,
              :intents,
              :quotes,
              :orders

  PRODUCTS = [
    ["premium_3m", "Premium 3m", "Telegram Premium 3 months", "Telegram Premium 3 міс.", "Premium 3 міс.", "telegram_premium"],
    ["premium_6m", "Premium 6m", "Telegram Premium 6 months", "Telegram Premium 6 міс.", "Premium 6 міс.", "telegram_premium"],
    ["premium_12m", "Premium 12m", "Telegram Premium 12 months", "Telegram Premium 12 міс.", "Premium 12 міс.", "telegram_premium"],
    ["stars_500", "Stars 500", "Stars 500", "Stars 500", "Stars 500", "telegram_stars"],
    ["stars_1000", "Stars 1000", "Stars 1000", "Stars 1000", "Stars 1000", "telegram_stars"],
    ["stars_3000", "Stars 3000", "Stars 3000", "Stars 3000", "Stars 3000", "telegram_stars"],
    ["ton", "TON", "TON", "TON", "TON", "crypto_asset"],
    ["btc", "BTC", "BTC", "BTC", "BTC", "crypto_asset"],
    ["eth", "ETH", "ETH", "ETH", "ETH", "crypto_asset"]
  ].freeze

  def initialize
    @requests = []
    @health_requests = 0
    @product_requests = 0
    @product_locales = []
    @price_proposal_requests = []
    @applied_prices = []
    @fx_rate_requests = 0
    @applied_fx_rates = []
    @intents = {}
    @quotes = {}
    @orders = {}
    @sequence = 0
  end

  def authenticate_telegram(user:, chat:)
    @requests << { user: user, chat: chat }
    role = user.fetch("id").to_s == "99" ? "admin" : "client"
    {
      "id" => ACTOR_USER_ID,
      "attributes" => {
        "role" => role,
        "status" => "active",
        "telegram_username" => user["username"]
      }
    }
  end

  def health
    @health_requests += 1
    { "status" => "ok", "server_time" => "2026-07-12T00:00:00.000000Z" }
  end

  def active_users
    [
      {
        "id" => ACTOR_USER_ID,
        "attributes" => {
          "telegram_user_id" => "77",
          "telegram_username" => "zero",
          "role" => "client",
          "status" => "active",
          "locale" => "uk_UA"
        }
      }
    ]
  end

  def products(locale: "en_US", currency: nil)
    @product_requests += 1
    @product_locales << locale
    PRODUCTS.each_with_index.map do |(sku, short_name, english_name, ukrainian_name, ukrainian_button, family), index|
      ukrainian = locale == "uk_UA"
      attributes = {
        "short_name" => short_name,
        "name" => ukrainian ? ukrainian_name : english_name,
        "button_label" => ukrainian ? ukrainian_button : short_name,
        "locale" => ukrainian ? "uk_UA" : "en_US",
        "metadata" => { "family" => family },
        "status" => "active",
        "position" => index + 1
      }
      attributes["price"] = {
        "amount" => "7.45",
        "currency" => currency || "USDT",
        "amount_usdt" => "7.45"
      } if currency
      { "type" => "product", "id" => sku, "attributes" => attributes }
    end
  end

  def currencies(locale: "en_US")
    %w[usdt usd uah rub].each_with_index.map do |sku, index|
      {
        "type" => "currency",
        "id" => sku,
        "attributes" => {
          "short_name" => sku.upcase,
          "name" => sku.upcase,
          "button_label" => sku.upcase,
          "locale" => locale,
          "metadata" => { "family" => "currency" },
          "status" => "active",
          "position" => 100 + index,
          "code" => sku.upcase,
          "usdt_per_unit" => sku == "usdt" ? "1" : nil
        }
      }
    end
  end

  def create_intent(capability:, payload:, context: {})
    id = next_id("intent")
    resource = {
      "type" => "intent",
      "id" => id,
      "attributes" => {
        "capability" => capability,
        "payload" => stringify(payload),
        "context" => stringify(context),
        "created_at" => "2026-07-31T14:00:00.000000Z"
      }
    }
    @intents[id] = resource
  end

  def intent(id)
    @intents.fetch(id)
  end

  def quote_intent(intent_id)
    id = next_id("quote")
    resource = {
      "type" => "quote",
      "id" => id,
      "attributes" => {
        "intent_id" => intent_id,
        "terms" => { "fulfillment" => "manual" },
        "expires_at" => "2026-07-31T14:15:00.000000Z",
        "created_at" => "2026-07-31T14:00:00.000000Z"
      }
    }
    @quotes[id] = resource
  end

  def quote(id)
    @quotes.fetch(id)
  end

  def accept_quote(id)
    quote = self.quote(id)
    intent = self.intent(quote.dig("attributes", "intent_id"))
    order_id = "order:#{id}"
    @orders[order_id] ||= {
      "type" => "order",
      "id" => order_id,
      "attributes" => {
        "intent_id" => intent.fetch("id"),
        "quote_id" => id,
        "capability" => intent.dig("attributes", "capability"),
        "payload" => intent.dig("attributes", "payload"),
        "context" => intent.dig("attributes", "context"),
        "terms" => quote.dig("attributes", "terms"),
        "status" => "accepted",
        "attempts" => 0,
        "progress" => nil,
        "result" => nil,
        "failure" => nil
      }
    }
  end

  def order(id)
    @orders.fetch(id)
  end

  def execute_order(id)
    resource = order(id)
    attributes = resource.fetch("attributes")
    return resource if %w[succeeded failed cancelled].include?(attributes.fetch("status"))

    attributes["status"] = "pending"
    attributes["attempts"] = 1
    attributes["progress"] = {
      "reference" => "task-1",
      "data" => { "status" => "awaiting_operator" }
    }
    resource
  end

  def complete_order(id)
    resource = order(id)
    attributes = resource.fetch("attributes")
    attributes["status"] = "succeeded"
    attributes["progress"] = nil
    attributes["result"] = {
      "reference" => "operator-result-1",
      "data" => { "delivered" => true }
    }
    resource
  end

  def price_proposal(actor_user_id:, locale: "en_US")
    @price_proposal_requests << { actor_user_id: actor_user_id, locale: locale }
    products(locale: locale).first(2).map do |product|
      {
        "type" => "price",
        "id" => product.fetch("id"),
        "attributes" => {
          "name" => product.dig("attributes", "name"),
          "position" => product.dig("attributes", "position"),
          "previous_amount_usdt" => "7.20",
          "current_amount_usdt" => "7.45",
          "current_edited_by_user_id" => ACTOR_USER_ID,
          "current_applied_at" => "2026-07-19T07:00:00.000000Z"
        }
      }
    end
  end

  def apply_prices(actor_user_id:, prices:)
    @applied_prices << { actor_user_id: actor_user_id, prices: prices }
    prices.map do |price|
      {
        "type" => "price",
        "id" => price.fetch(:sku),
        "attributes" => { "amount_usdt" => price.fetch(:amount_usdt) }
      }
    end
  end

  def fx_rates
    @fx_rate_requests += 1
    [["USDT", "1"], ["EUR", "1.16"]].map do |currency, value|
      {
        "type" => "fx_rate",
        "id" => currency,
        "attributes" => {
          "currency" => currency,
          "usdt_per_unit" => value,
          "updated_at" => "2026-07-19T07:00:00.000000Z"
        }
      }
    end
  end

  def set_fx_rates(actor_user_id:, rates:)
    @applied_fx_rates << { actor_user_id: actor_user_id, rates: rates }
    rates.map do |rate|
      {
        "type" => "fx_rate",
        "id" => rate.fetch(:currency),
        "attributes" => {
          "currency" => rate.fetch(:currency),
          "usdt_per_unit" => rate.fetch(:usdt_per_unit)
        }
      }
    end
  end

  def set_admin(actor_user_id:, target:)
    @requests << { actor_user_id: actor_user_id, target: target }
    {
      "id" => "87654321-4321-4000-8000-210987654321",
      "attributes" => {
        "telegram_user_id" => "88",
        "telegram_username" => "target_user",
        "telegram_chat_id" => "880",
        "role" => "admin",
        "status" => "active"
      },
      "meta" => { "changed" => true }
    }
  end

  private

  def next_id(prefix)
    @sequence += 1
    "#{prefix}-#{@sequence}"
  end

  def stringify(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, item), result| result[key.to_s] = stringify(item) }
    when Array
      value.map { |item| stringify(item) }
    else
      value
    end
  end
end

class FakeTelegramAPI
  attr_reader :messages,
              :edited_messages,
              :command_sets,
              :deleted_messages,
              :answered_callbacks

  def initialize
    @messages = []
    @edited_messages = []
    @command_sets = []
    @deleted_messages = []
    @answered_callbacks = []
  end

  def send_message(chat_id:, text:, reply_markup: nil, parse_mode: nil)
    rendered_text = rendered(text, parse_mode)
    message = {
      "message_id" => @messages.length + 1,
      chat_id: chat_id,
      text: rendered_text,
      raw_text: text,
      parse_mode: parse_mode,
      reply_markup: reply_markup
    }
    @messages << message
    message
  end

  def edit_message_text(chat_id:, message_id:, text:, reply_markup: nil, parse_mode: nil)
    message = {
      "message_id" => message_id,
      chat_id: chat_id,
      text: rendered(text, parse_mode),
      raw_text: text,
      parse_mode: parse_mode,
      reply_markup: reply_markup
    }
    @edited_messages << message
    message
  end

  def answer_callback_query(callback_query_id:, text: nil)
    @answered_callbacks << { callback_query_id: callback_query_id, text: text }
  end

  def delete_message(chat_id:, message_id:)
    @deleted_messages << { chat_id: chat_id, message_id: message_id }
  end

  def set_commands(commands, scope: nil)
    @command_sets << { commands: commands, scope: scope }
  end

  private

  def rendered(text, parse_mode)
    parse_mode == "HTML" ? CGI.unescapeHTML(text.gsub(%r{</?a\b[^>]*>}, "")) : text
  end
end
