# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/bot"
require "zero_x_da/market/telegram_bot/bot_special_checkout"

class SpecialCheckoutTest < Minitest::Test
  Account = ZeroXDA::Market::TelegramBot::NilxIdentityAPI::Account
  Configuration = ZeroXDA::Market::TelegramBot::BotSpecialCheckout::Configuration
  LINK_URL = "https://t.me/nilx_one_test_bot/app?startapp=link"

  # Identity's partner answer for each Telegram user id, or an error.
  class FakeIdentity
    attr_accessor :accounts
    attr_reader :asked

    def initialize(accounts)
      @accounts = accounts
      @asked = []
    end

    def telegram_account(telegram_user_id)
      @asked << telegram_user_id
      answer = @accounts.fetch(telegram_user_id)
      raise ZeroXDA::Market::TelegramBot::NilxIdentityAPI::Error, "offline" if answer == :down

      answer
    end
  end

  # Market's seeds offers and issuer orders, as the bot sees them.
  module IssuerOrders
    attr_reader :issuer_orders, :issuer_calls

    def denomination_prices(code, locale:)
      raise ArgumentError unless code == "seeds"

      [{ "type" => "denomination_price", "id" => "0x1_special_1m",
         "attributes" => { "sku" => "0x1_special_1m", "amount_minor" => 640, "denomination" => "seeds" } }]
    end

    def create_issuer_order(customer:, sku:, denomination:, idempotency_key:)
      (@issuer_calls ||= []) << [:create, customer, sku, denomination, idempotency_key]
      @issuer_orders ||= {}
      existing = @issuer_orders.values.find { |order| order[:key] == idempotency_key }
      return existing.fetch(:document) if existing

      id = "order-#{@issuer_orders.length + 1}"
      document = { "type" => "issuer_order", "id" => id,
                   "attributes" => { "sku" => sku, "status" => "pending", "rejection_code" => nil } }
      @issuer_orders[id] = { key: idempotency_key, document: document }
      document
    end

    def issuer_order(id, customer:)
      (@issuer_calls ||= []) << [:read, customer, id]
      @issuer_orders.fetch(id).fetch(:document)
    end

    def cancel_issuer_order(id, customer:)
      (@issuer_calls ||= []) << [:cancel, customer, id]
      document = @issuer_orders.fetch(id).fetch(:document)
      unless document.dig("attributes", "status") == "pending"
        raise ZeroXDA::Market::TelegramBot::MarketAPI::Error.new("claimed", code: "issuer_order_not_pending")
      end

      document["attributes"]["status"] = "cancelled"
      document
    end

    def settle(id, status, rejection_code = nil)
      attributes = @issuer_orders.fetch(id).fetch(:document).fetch("attributes")
      attributes["status"] = status
      attributes["rejection_code"] = rejection_code
    end
  end

  def setup
    @market = FakeMarketAPI.new.extend(IssuerOrders)
    @telegram = FakeTelegramAPI.new
    @identity = FakeIdentity.new(77 => linked(seeds: 10_000))
    @now = Time.utc(2026, 10, 31, 12, 0, 0)
    @bot = ZeroXDA::Market::TelegramBot::Bot.new(
      special_checkout: Configuration.new(identity: @identity, link_url: LINK_URL),
      market_api: @market, telegram_api: @telegram, clock: -> { @now }, status_message_ttl: 0
    )
  end

  def test_a_linked_bond_sees_its_wallet_and_buys_special_after_confirming
    @bot.handle(callback("v:0x1_special_1m"))
    offer = screen
    assert_includes offer.fetch(:text), "Bond 0x1: zero"
    assert_includes offer.fetch(:text), "Баланс: 10000 ₴€£"
    assert_equal "x:0x1_special_1m", button(offer, "Купити за 640 ₴€£")
    assert_nil @market.issuer_orders

    @bot.handle(callback("x:0x1_special_1m"))
    confirm = screen
    assert_equal "Сплатити 640 ₴€£ з гаманця zero за 0x1 Special 1 months?", confirm.fetch(:text)
    pay = button(confirm, "Сплатити 640 ₴€£")
    assert_match(/\Ak:0x1_special_1m:[a-z0-9]+\z/, pay)
    assert_nil @market.issuer_orders

    @bot.handle(callback(pay))
    pending = screen
    assert_includes pending.fetch(:text), "0x1 списує з гаманця"
    assert_equal "w:order-1", button(pending, "↻ Оновити")
    assert_equal "u:order-1", button(pending, "Скасувати замовлення")
    _, customer, sku, denomination, key = @market.issuer_calls.first
    assert_equal({ user_id: FakeMarketAPI::ACTOR_USER_ID, telegram_user_id: 77 }, customer)
    assert_equal %w[0x1_special_1m seeds], [sku, denomination]
    assert_match(/\Atg\.77\.[a-z0-9]+\.0x1_special_1m\z/, key)

    # A double tap on the same confirmation replays the one order.
    @bot.handle(callback(pay))
    assert_equal 1, @market.issuer_orders.length

    @market.settle("order-1", "fulfilled")
    @bot.handle(callback("w:order-1"))
    paid = screen
    assert_includes paid.fetch(:text), "Оплачено ✅ 0x1 Special 1 months — твоя."
    assert_includes paid.fetch(:text), "xPing летить до 0xda-market"
    assert_includes paid.fetch(:text), "лишиться «Оплачено»"
  end

  def test_a_bond_that_holds_special_is_never_offered_a_purchase
    @identity.accounts[77] = linked(seeds: 10_000, open: false, ends: Time.utc(2026, 11, 30, 12))
    @bot.handle(callback("v:0x1_special_1m"))
    offer = screen
    assert_includes offer.fetch(:text), "Special уже твоя до 2026-11-30"
    refute(buttons(offer).any? { |entry| entry[:callback_data].to_s.start_with?("x:", "k:") })

    # Neither a forged confirmation nor a forged order button places an order.
    @bot.handle(callback("x:0x1_special_1m"))
    refute(buttons(screen).any? { |entry| entry[:callback_data].to_s.start_with?("k:") })
    @bot.handle(callback("k:0x1_special_1m:abc"))
    assert_nil @market.issuer_orders
  end

  def test_not_enough_seeds_offers_no_purchase
    @identity.accounts[77] = linked(seeds: 639)
    @bot.handle(callback("v:0x1_special_1m"))
    assert_equal "n", button(screen, "Недостатньо сідів (639 ₴€£)")
    @bot.handle(callback("k:0x1_special_1m:abc"))
    assert_nil @market.issuer_orders
  end

  def test_an_unlinked_telegram_account_is_asked_to_sign_in_to_0x1
    @identity.accounts[77] = unlinked
    @bot.handle(callback("v:0x1_special_1m"))
    sign_in = screen
    assert_includes sign_in.fetch(:text), "Привʼяжи цей Telegram до свого Bond у 0x1"
    assert_equal LINK_URL, buttons(sign_in).find { |entry| entry[:text] == "Авторизуватися у 0x1" }.fetch(:url)
    assert_equal "v:0x1_special_1m", button(sign_in, "Я привʼязав · перевірити")

    # After connecting, the same check shows the wallet.
    @identity.accounts[77] = linked(seeds: 5000)
    @bot.handle(callback("v:0x1_special_1m"))
    assert_includes screen.fetch(:text), "Баланс: 5000 ₴€£"
  end

  def test_a_bond_that_already_has_another_telegram_account_is_explained
    @identity.accounts[77] = unlinked(refusal: "provider_type_already_linked")
    @bot.handle(callback("v:0x1_special_1m"))
    assert_includes screen.fetch(:text), "уже привʼязаний до іншого акаунта Telegram"
    @bot.handle(callback("k:0x1_special_1m:abc"))
    assert_nil @market.issuer_orders
  end

  def test_an_unreachable_identity_is_never_shown_as_signed_out
    @identity.accounts[77] = :down
    @bot.handle(callback("v:0x1_special_1m"))
    assert_includes screen.fetch(:text), "0x1 зараз не відповідає"
    refute_includes screen.fetch(:text), "Привʼяжи"
    @bot.handle(callback("k:0x1_special_1m:abc"))
    assert_nil @market.issuer_orders
  end

  def test_a_pending_order_can_be_cancelled_and_a_claimed_one_is_shown_as_it_is
    @bot.handle(callback("k:0x1_special_1m:a1"))
    @bot.handle(callback("u:order-1"))
    assert_includes screen.fetch(:text), "Замовлення скасовано. Нічого не списано."

    @bot.handle(callback("k:0x1_special_1m:a2"))
    @market.settle("order-2", "processing")
    @bot.handle(callback("u:order-2"))
    refute(buttons(screen).any? { |entry| entry[:callback_data] == "u:order-2" })
    assert_includes screen.fetch(:text), "0x1 списує з гаманця"
  end

  def test_issuer_rejections_say_nothing_was_charged
    @bot.handle(callback("k:0x1_special_1m:a1"))
    @market.settle("order-1", "rejected", "special_active")
    @bot.handle(callback("w:order-1"))
    assert_includes screen.fetch(:text), "0x1 не прийняв оплату (Special уже активна). Нічого не списано."

    @bot.handle(callback("k:0x1_special_1m:a2"))
    @market.settle("order-2", "rejected", "authorization_expired")
    @bot.handle(callback("w:order-2"))
    assert_includes screen.fetch(:text), "не підтвердилось вчасно"
  end

  def test_exclusive_stays_a_preview
    @bot.handle(callback("v:0x1_exclusive_1m"))
    assert_includes screen.fetch(:text), "0x1 Exclusive 1 months"
    @bot.handle(callback("x:0x1_exclusive_1m"))
    assert_includes @telegram.answered_callbacks.last.fetch(:text), "поки недоступна"
    @bot.handle(callback("k:0x1_exclusive_1m:abc"))
    assert_nil @market.issuer_orders
    assert_empty @identity.asked
  end

  private

  def linked(seeds:, open: true, ends: nil)
    Account.new(state: "linked", pub_dress: "zero", seeds: seeds, special_held: !open, special_ends_at: ends,
                purchase_open: open, link_refusal: nil)
  end

  def unlinked(refusal: nil)
    Account.new(state: "sign_in_required", pub_dress: nil, seeds: nil, special_held: false, special_ends_at: nil,
                purchase_open: false, link_refusal: refusal)
  end

  def screen
    @telegram.edited_messages.last
  end

  def buttons(message)
    message.dig(:reply_markup, :inline_keyboard).flatten
  end

  def button(message, text)
    found = buttons(message).find { |entry| entry[:text] == text }
    assert found, "no #{text.inspect} in #{buttons(message).map { |entry| entry[:text] }.inspect}"
    found[:callback_data]
  end

  def callback(data, user_id: 77)
    {
      "callback_query" => {
        "id" => "callback-#{@telegram.answered_callbacks.length + 1}",
        "data" => data,
        "from" => { "id" => user_id, "username" => "zero", "first_name" => "Sasha", "language_code" => "uk" },
        "message" => { "message_id" => 42, "chat" => { "id" => 770, "type" => "private" } }
      }
    }
  end
end
