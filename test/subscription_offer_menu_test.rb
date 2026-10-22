# frozen_string_literal: true
# © 2026 aiaiaiai · aiaiaiai.org

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/subscription_offer_menu"

class SubscriptionOfferMenuTest < Minitest::Test
  def setup
    @menu = ZeroXDA::Market::TelegramBot::SubscriptionOfferMenu.new
  end

  def test_seed_quantity_follows_ukrainian_plural_forms
    { 1 => "1 сід", 2 => "2 сіди", 4 => "4 сіди", 5 => "5 сідів",
      11 => "11 сідів", 14 => "14 сідів", 21 => "21 сід",
      22 => "22 сіди", 400 => "400 сідів" }.each do |count, label|
      result = @menu.build(product: special(count), locale: "uk_UA")
      assert_equal label, result.reply_markup.dig(:inline_keyboard, 1, 0, :text)
    end
  end

  def test_money_uses_authoritative_preview_only_with_usdt_fallback
    result = @menu.build(product: special(400, preview_price: {
      "amount" => "104", "currency" => "UAH"
    }), locale: "uk_UA")
    assert_equal "104 UAH", result.reply_markup.dig(:inline_keyboard, 1, 1, :text)

    missing = @menu.build(product: special(400), locale: "uk_UA")
    assert_equal "— USDT", missing.reply_markup.dig(:inline_keyboard, 1, 1, :text)
    assert_equal "Баланс: — ₴€£", missing.reply_markup.dig(:inline_keyboard, 2, 2, :text)
    assert_equal "Баланс: 0 ₴€£",
                 @menu.build(product: special(400), locale: "uk_UA", seed_balance: 0)
                      .reply_markup.dig(:inline_keyboard, 2, 2, :text)
    assert_equal "Баланс: — ₴€£",
                 @menu.build(product: special(400), locale: "uk_UA", seed_balance: "500")
                      .reply_markup.dig(:inline_keyboard, 2, 2, :text)
  end

  def test_exclusive_has_no_invented_seeds_price
    product = special(400)
    product["id"] = "0x1_exclusive_1m"
    product.fetch("attributes").fetch("metadata")["tier"] = "exclusive"
    product.fetch("attributes").fetch("metadata").delete("seed_price")
    result = @menu.build(product: product, locale: "uk_UA")
    assert_equal "— ₴€£", result.reply_markup.dig(:inline_keyboard, 1, 0, :text)
    refute result.reply_markup.fetch(:inline_keyboard).flatten.any? { |button|
      button.fetch(:callback_data).start_with?("q:")
    }
  end

  private

  def special(amount, preview_price: nil)
    {
      "id" => "0x1_special_1m",
      "attributes" => {
        "name" => "0x1 Special · 1 місяць",
        "metadata" => {
          "family" => "0x1_subscription", "tier" => "special",
          "seed_price" => { "currency" => "seeds", "amount" => amount, "symbol" => "₴€£" }
        },
        "preview_price" => preview_price
      }
    }
  end
end
