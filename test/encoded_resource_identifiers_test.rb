# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/encoded_resource_identifiers"

class EncodedResourceIdentifiersTest < Minitest::Test
  def setup
    @app = ZeroXDA::Market::TelegramBot::TelegramMiniApp.allocate
  end

  def test_decodes_a_browser_encoded_core_order_identifier_before_validation
    assert_equal(
      "order:b29b79fd-37e1-4021-a99e-cd8a577dae44",
      @app.send(:resource_id, "order%3Ab29b79fd-37e1-4021-a99e-cd8a577dae44")
    )
  end

  def test_rejects_an_encoded_path_separator_after_decoding
    error = assert_raises(ArgumentError) do
      @app.send(:resource_id, "order%2Fother")
    end

    assert_equal "resource id is invalid", error.message
  end
end
