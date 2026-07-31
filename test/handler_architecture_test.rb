# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market_client_bot/bot"

class HandlerArchitectureTest < Minitest::Test
  Bot = ZeroXDA::MarketClientBot::Bot
  AdminMessages = ZeroXDA::MarketClientBot::AdminMessages
  StatusCards = ZeroXDA::MarketClientBot::StatusCards
  ADMIN_HANDLERS = %i[
    show_servers
    refresh_servers
    show_active_users
    start_price_application
    show_fx_rates
    set_admin
  ].freeze

  def test_administrator_handlers_have_one_canonical_owner
    ADMIN_HANDLERS.each do |handler|
      assert_equal AdminMessages, Bot.instance_method(handler).owner, handler
      refute_includes Bot.private_instance_methods(false), handler
    end
  end

  def test_status_callback_dispatch_has_one_canonical_owner
    assert_equal StatusCards, Bot.instance_method(:handle_callback).owner
  end

  def test_legacy_shadowing_modules_are_not_loaded
    refute ZeroXDA::MarketClientBot.const_defined?(:TelegramUserLinks, false)
    refute ZeroXDA::MarketClientBot.const_defined?(:LocalizedLegacyCopy, false)
    refute ZeroXDA::MarketClientBot.const_defined?(:LocalizedServerStartNotice, false)
  end
end
