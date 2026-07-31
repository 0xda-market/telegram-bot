require_relative "test_helper"
require "zero_x_da/market_client_bot/bot"

class BotTest < Minitest::Test
  ACTOR_USER_ID = FakeMarketAPI::ACTOR_USER_ID

  def setup
    @market = FakeMarketAPI.new
    @telegram = FakeTelegramAPI.new
    @bot = build_bot
  end

  def test_start_authenticates_and_installs_the_client_menu
    @bot.handle(update("/start"))

    assert_equal 1, @market.requests.length
    card = @telegram.messages.first
    assert_includes card.fetch(:text), "авторизація успішна"
    assert_equal "s:a", card.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    commands = @telegram.command_sets.first
    assert_equal({ type: "chat", chat_id: 770 }, commands.fetch(:scope))
    assert_equal %w[buy status], commands.fetch(:commands).map { |item| item.fetch(:command) }
    assert_empty @telegram.deleted_messages
  end

  def test_status_displays_a_persistent_card_and_deletes_only_the_command
    @bot.handle(update("/status"))

    card = @telegram.messages.last
    assert_includes card.fetch(:text), "role: client"
    assert_includes card.fetch(:text), "status: active ✅"
    assert_equal "s:a", card.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    assert_equal [{ chat_id: 770, message_id: 10 }], @telegram.deleted_messages
    assert_equal 0, @market.health_requests
  end

  def test_account_status_refresh_survives_restart_and_edits_the_same_card
    restarted = build_bot

    restarted.handle(callback("s:a", message_id: 42))

    card = @telegram.edited_messages.last
    assert_equal 42, card.fetch("message_id")
    assert_includes card.fetch(:text), "status: active ✅"
    assert_equal "s:a", card.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    assert_equal "callback-1", @telegram.answered_callbacks.last.fetch(:callback_query_id)
  end

  def test_buy_opens_grouped_catalog_and_never_truncates_to_nine_buttons
    @bot.handle(update("/buy"))

    root = @telegram.messages.last
    assert_equal "обери продукт для купівлі:", root.fetch(:text)
    category_buttons = root.dig(:reply_markup, :inline_keyboard).flatten
    assert_equal 3, category_buttons.length
    assert_equal %w[c:b:premium_3m c:b:stars_500 c:b:ton], category_buttons.map { |button| button.fetch(:callback_data) }

    category_buttons.each do |button|
      @bot.handle(callback(button.fetch(:callback_data)))
    end
    product_callbacks = @telegram.edited_messages.flat_map do |message|
      message.dig(:reply_markup, :inline_keyboard).flatten.map { |button| button[:callback_data] }
    end.compact.grep(/\Ab:/)

    assert_equal FakeMarketAPI::PRODUCTS.map(&:first).sort, product_callbacks.map { |data| data.delete_prefix("b:") }.sort
  end

  def test_purchase_selection_creates_quote_then_explicit_acceptance_and_durable_pending_order
    @bot.handle(callback("b:premium_3m"))

    quote_screen = @telegram.edited_messages.last
    assert_includes quote_screen.fetch(:text), "Пропозиція купівлі"
    assert_includes quote_screen.fetch(:text), "7.45 USDT"
    assert_includes quote_screen.fetch(:text), "Дійсна до"
    accept_callback = quote_screen.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    assert_match(/\Aq:quote-\d+\z/, accept_callback)

    intent = @market.intents.values.first
    assert_equal "manual.fulfillment", intent.dig("attributes", "capability")
    assert_equal "purchase", intent.dig("attributes", "payload", "action")
    assert_equal "premium_3m", intent.dig("attributes", "payload", "product", "sku")
    assert_equal ACTOR_USER_ID, intent.dig("attributes", "context", "customer_user_id")

    @bot.handle(callback(accept_callback))

    pending_screen = @telegram.edited_messages.last
    assert_includes pending_screen.fetch(:text), "Заявку прийнято"
    assert_includes pending_screen.fetch(:text), "стан замовлення збережено"
    refresh_callback = pending_screen.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    assert_match(/\Ao:order:quote-\d+\z/, refresh_callback)
    assert_equal "pending", @market.orders.values.first.dig("attributes", "status")
  end

  def test_refresh_returns_the_final_receipt_after_operator_completion
    @bot.handle(callback("b:premium_3m"))
    accept_callback = @telegram.edited_messages.last.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    @bot.handle(callback(accept_callback))
    order_id = @market.orders.keys.first
    @market.complete_order(order_id)

    @bot.handle(callback("o:#{order_id}"))

    receipt = @telegram.edited_messages.last
    assert_includes receipt.fetch(:text), "Купівлю завершено ✅"
    assert_includes receipt.fetch(:text), order_id
    assert_includes receipt.fetch(:text), "Telegram Premium 3 міс."
    assert_includes receipt.fetch(:text), "7.45 USDT"
    assert_equal "h:b", receipt.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
  end

  def test_admin_servers_and_users_remain_role_scoped
    @bot.handle(update("/servers", user_id: 99, chat_id: 990))
    servers = @telegram.messages.first
    assert_includes servers.fetch(:text), "✅ Market core"
    assert_equal "s:s", servers.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
    assert_equal [{ chat_id: 990, message_id: 10 }], @telegram.deleted_messages

    @bot.handle(update("/users", user_id: 99, chat_id: 990))
    users = @telegram.messages.last.fetch(:text)
    assert_includes users, "👥 Активні користувачі: 1"
    assert_includes users, "@zero"
    refute_includes users, ACTOR_USER_ID
  end

  def test_server_status_refresh_is_stateless_and_edits_the_same_card
    @bot.handle(callback("s:s", user_id: 99, chat_id: 990, message_id: 73))

    assert_equal 1, @market.health_requests
    card = @telegram.edited_messages.last
    assert_equal 73, card.fetch("message_id")
    assert_includes card.fetch(:text), "🖥️ Стан сервісів"
    assert_includes card.fetch(:text), "✅ Client bot"
    assert_equal "s:s", card.dig(:reply_markup, :inline_keyboard, 0, 0, :callback_data)
  end

  def test_non_admin_cannot_refresh_server_status
    @bot.handle(callback("s:s"))

    assert_equal 0, @market.health_requests
    assert_empty @telegram.edited_messages
    assert_equal "Доступ заборонено.", @telegram.answered_callbacks.last.fetch(:text)
  end

  def test_non_admin_cannot_use_admin_commands
    @bot.handle(update("/servers"))
    assert_equal "Доступ заборонено.", @telegram.messages.last.fetch(:text)
    assert_equal 0, @market.health_requests

    @bot.handle(update("/set_admin 88"))
    assert_equal "Доступ заборонено.", @telegram.messages.last.fetch(:text)
  end

  def test_admin_promotes_a_user_and_installs_their_menu
    @bot.handle(update("/set_admin @target_user", user_id: 99, chat_id: 990))

    request = @market.requests.last
    assert_equal ACTOR_USER_ID, request.fetch(:actor_user_id)
    assert_equal "@target_user", request.fetch(:target)
    command_set = @telegram.command_sets.last
    assert_equal({ type: "chat", chat_id: "880" }, command_set.fetch(:scope))
    assert_includes @telegram.messages.last.fetch(:text), "Вам призначено роль admin"
  end

  def test_price_application_form_uses_authenticated_actor_uuid
    @bot.handle(update("/apply_prices", user_id: 99, chat_id: 990))

    assert_equal [{ actor_user_id: ACTOR_USER_ID, locale: "uk_UA" }], @market.price_proposal_requests
    assert_includes @telegram.messages.last.fetch(:text), "📦 Застосування цін"
    assert_includes @telegram.messages.last.fetch(:text), "✏️ @zero"
  end

  def test_admin_applies_a_price_directly
    @bot.handle(update("/apply_price premium_6m 7.45", user_id: 99, chat_id: 990))

    assert_equal(
      [{ actor_user_id: ACTOR_USER_ID, prices: [{ sku: "premium_6m", amount_usdt: "7.45" }] }],
      @market.applied_prices
    )
    assert_includes @telegram.messages.last.fetch(:text), "Ціну застосовано ✅"
  end

  def test_price_reply_survives_bot_restart_without_process_memory
    @bot.handle(update("/apply_price premium_6m", user_id: 99, chat_id: 990))
    prompt = @telegram.messages.last
    assert_includes prompt.fetch(:text), "[price:premium_6m]"
    assert_equal true, prompt.dig(:reply_markup, :force_reply)
    refute_includes @bot.instance_variables, :@price_dialogs

    restarted = build_bot
    restarted.handle(
      update(
        "7.45",
        user_id: 99,
        chat_id: 990,
        reply_to_message: { "text" => prompt.fetch(:text) }
      )
    )

    assert_equal "premium_6m", @market.applied_prices.last.fetch(:prices).first.fetch(:sku)
    assert_includes @telegram.messages.last.fetch(:text), "Ціну застосовано ✅"
  end

  def test_unmatched_numeric_message_explains_how_to_continue
    @bot.handle(update("7.45", user_id: 99, chat_id: 990))

    assert_includes @telegram.messages.last.fetch(:text), "не прив’язане до запиту ціни"
    assert_empty @market.applied_prices
  end

  def test_apply_price_without_arguments_opens_grouped_catalog_including_currencies
    @bot.handle(update("/apply_price", user_id: 99, chat_id: 990))

    callbacks = @telegram.messages.last.dig(:reply_markup, :inline_keyboard).flatten.map do |button|
      button.fetch(:callback_data)
    end
    assert_includes callbacks, "c:p:premium_3m"
    assert_includes callbacks, "c:p:usdt"
  end

  def test_compatibility_rate_commands_use_currency_resources_and_generic_prices
    @bot.handle(update("/rates", user_id: 99, chat_id: 990))
    listing = @telegram.messages.last.fetch(:text)
    assert_includes listing, "💱 Ціни валют"
    assert_includes listing, "1 UAH = 0.024 USDT"

    @bot.handle(update("/set_rate uah 0.025", user_id: 99, chat_id: 990))

    assert_equal(
      {
        actor_user_id: ACTOR_USER_ID,
        prices: [{ sku: "uah", amount_usdt: "0.025" }]
      },
      @market.applied_prices.last
    )
    assert_includes @telegram.messages.last.fetch(:text), "Ціну валюти застосовано ✅"
    assert_includes @telegram.messages.last.fetch(:text), "1 UAH = 0.025 USDT"
    assert_equal %w[uk_UA uk_UA], @market.currency_requests.last(2)
  end

  def test_set_rate_rejects_a_currency_absent_from_the_core_catalog
    @bot.handle(update("/set_rate eur 1.16", user_id: 99, chat_id: 990))

    assert_empty @market.applied_prices
    assert_includes @telegram.messages.last.fetch(:text), "EUR"
    assert_includes @telegram.messages.last.fetch(:text), "не зареєстрована"
  end

  def test_legacy_setadmin_command_is_ignored
    @bot.handle(update("/setadmin 88", user_id: 99, chat_id: 990))

    assert_empty @market.requests
    assert_empty @telegram.command_sets
    assert_empty @telegram.messages
  end

  def test_ignores_unknown_non_numeric_messages
    @bot.handle(update("hello"))

    assert_empty @market.requests
    assert_empty @telegram.messages
  end

  def test_reports_a_slow_market_start_and_sends_the_result_later
    slow_market = Class.new(FakeMarketAPI) do
      def authenticate_telegram(**arguments)
        sleep 0.03
        super
      end
    end.new
    bot = ZeroXDA::MarketClientBot::Bot.new(
      market_api: slow_market,
      telegram_api: @telegram,
      server_start_notice_delay: 0.005
    )

    bot.handle(update("/start"))

    assert_equal "Сервер запускається…", @telegram.messages.first.fetch(:text)
    assert_includes @telegram.messages.last.fetch(:text), "авторизація успішна"
  end

  private

  def build_bot
    ZeroXDA::MarketClientBot::Bot.new(
      market_api: @market,
      telegram_api: @telegram,
      clock: -> { Time.utc(2026, 7, 12, 0, 0, 1) },
      status_message_ttl: 0
    )
  end

  def update(text, user_id: 77, chat_id: 770, language_code: "uk", reply_to_message: nil)
    message = {
      "message_id" => 10,
      "text" => text,
      "from" => {
        "id" => user_id,
        "username" => "zero",
        "first_name" => "Sasha",
        "language_code" => language_code
      },
      "chat" => { "id" => chat_id, "type" => "private" }
    }
    message["reply_to_message"] = reply_to_message if reply_to_message
    { "message" => message }
  end

  def callback(data, user_id: 77, chat_id: 770, language_code: "uk", message_id: 42)
    {
      "callback_query" => {
        "id" => "callback-#{@telegram.answered_callbacks.length + 1}",
        "data" => data,
        "from" => {
          "id" => user_id,
          "username" => "zero",
          "first_name" => "Sasha",
          "language_code" => language_code
        },
        "message" => {
          "message_id" => message_id,
          "chat" => { "id" => chat_id, "type" => "private" }
        }
      }
    }
  end
end
