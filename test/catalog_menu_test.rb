# frozen_string_literal: true

require_relative "test_helper"
require "zero_x_da/market/telegram_bot/catalog_menu"

class CatalogMenuTest < Minitest::Test
  CatalogMenu = ZeroXDA::Market::TelegramBot::CatalogMenu

  def test_stateless_category_pages_cover_every_product_beyond_nine
    menu = CatalogMenu.new
    products = Array.new(14) { |index| product(index + 1) }

    first = menu.category(products: products, mode: "b", anchor_sku: "item_1", locale: "uk_UA")
    second = menu.category(products: products, mode: "b", anchor_sku: "item_7", locale: "uk_UA")
    third = menu.category(products: products, mode: "b", anchor_sku: "item_13", locale: "uk_UA")

    callbacks = [first, second, third].flat_map do |screen|
      screen.reply_markup.fetch(:inline_keyboard).flatten.filter_map do |button|
        data = button.fetch(:callback_data)
        data if data.start_with?("b:")
      end
    end

    assert_equal Array.new(14) { |index| "b:item_#{index + 1}" }, callbacks
    assert_equal "c:b:item_7", first.reply_markup.dig(:inline_keyboard, -1, 2, :callback_data)
    assert_equal "c:b:item_1", second.reply_markup.dig(:inline_keyboard, -1, 0, :callback_data)
    assert_equal "h:b", second.reply_markup.dig(:inline_keyboard, -1, 1, :callback_data)
    assert_equal "c:b:item_13", second.reply_markup.dig(:inline_keyboard, -1, 2, :callback_data)
  end

  def test_every_callback_fits_telegram_limit
    menu = CatalogMenu.new
    products = Array.new(14) { |index| product(index + 1) }
    screens = [
      menu.root(products: products, mode: "b", locale: "en_US"),
      menu.category(products: products, mode: "b", anchor_sku: "item_7", locale: "en_US")
    ]

    screens.each do |screen|
      screen.reply_markup.fetch(:inline_keyboard).flatten.each do |button|
        assert_operator button.fetch(:callback_data).bytesize, :<=, 64
      end
    end
  end

  private

  def product(position)
    {
      "type" => "product",
      "id" => "item_#{position}",
      "attributes" => {
        "name" => "Item #{position}",
        "button_label" => "Item #{position}",
        "metadata" => { "family" => "telegram_stars" },
        "position" => position
      }
    }
  end
end
