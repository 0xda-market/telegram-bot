# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/bot"

class HandlerArchitectureTest < Minitest::Test
  Bot = ZeroXDA::Market::TelegramBot::Bot
  AdminMessages = ZeroXDA::Market::TelegramBot::AdminMessages
  StatusCards = ZeroXDA::Market::TelegramBot::StatusCards
  MarketAPI = ZeroXDA::Market::TelegramBot::MarketAPI
  ADMIN_HANDLERS = %i[
    show_servers
    refresh_servers
    show_active_users
    start_price_application
    show_currency_prices
    set_admin
  ].freeze

  def test_administrator_handlers_have_one_canonical_owner
    ADMIN_HANDLERS.each do |handler|
      assert_equal AdminMessages, Bot.instance_method(handler).owner, handler
      refute_includes Bot.private_instance_methods(false), handler
    end
  end

  def test_currency_price_write_has_one_canonical_owner
    assert_equal Bot, Bot.instance_method(:set_currency_price).owner
    refute_includes Bot.private_instance_methods, :set_fx_rate
  end

  def test_market_api_exposes_only_core_currency_and_price_contracts
    refute_includes MarketAPI.instance_methods(false), :fx_rates
    refute_includes MarketAPI.instance_methods(false), :set_fx_rates
    assert_includes MarketAPI.instance_methods(false), :currencies
    assert_includes MarketAPI.instance_methods(false), :apply_prices
  end

  def test_status_callback_dispatch_has_one_canonical_owner
    assert_equal StatusCards, Bot.instance_method(:handle_callback).owner
  end

  def test_legacy_shadowing_modules_are_not_loaded
    refute ZeroXDA::Market::TelegramBot.const_defined?(:TelegramUserLinks, false)
    refute ZeroXDA::Market::TelegramBot.const_defined?(:LocalizedLegacyCopy, false)
    refute ZeroXDA::Market::TelegramBot.const_defined?(:LocalizedServerStartNotice, false)
  end
end
