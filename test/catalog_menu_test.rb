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

  def test_0x1_eight_products_fit_on_first_page_in_four_by_three_matrix
    menu = CatalogMenu.new
    products = %w[special exclusive].flat_map do |tier|
      [12, 6, 3, 1].map { |months| subscription(tier, months) }
    end

    screen = menu.category(
      products: products, mode: "b", anchor_sku: "0x1_special_12m", locale: "uk_UA"
    )
    rows = screen.reply_markup.fetch(:inline_keyboard)
    assert_equal "Обери підписку 0x1:", screen.title
    assert screen.has_previews
    assert_equal 5, rows.length
    assert_equal ["·", "Exclusive 1 місяць", "·"], rows[0].map { |b| b.fetch(:text) }
    assert_equal ["Exclusive 3 міс.", "Exclusive 6 міс.", "Exclusive 12 міс."],
                 rows[1].map { |b| b.fetch(:text) }
    assert_equal ["·", "Special 1 місяць", "·"], rows[2].map { |b| b.fetch(:text) }
    assert_equal ["Special 3 міс.", "Special 6 міс.", "Special 12 міс."],
                 rows[3].map { |b| b.fetch(:text) }
    assert_equal %w[n h:b n], rows.last.map { |b| b.fetch(:callback_data) }
    assert_equal 8, rows.flatten.count { |b| b.fetch(:callback_data).start_with?("v:") }
    assert rows.flatten.all? { |b| b.fetch(:callback_data).bytesize <= 64 }
  end

  def test_0x1_subscription_callback_remains_preview_only_when_upstream_marks_active
    entry = subscription("exclusive", 1)
    entry.fetch("attributes")["status"] = "active"
    entry.fetch("attributes")["preview"] = false
    screen = CatalogMenu.new.category(products: [entry], mode: "b", anchor_sku: entry.fetch("id"))
    assert screen.has_previews
    assert_equal "v:0x1_exclusive_1m",
                 screen.reply_markup.dig(:inline_keyboard, 0, 0, :callback_data)
  end

  def test_ninth_0x1_product_moves_to_next_page
    menu = CatalogMenu.new
    products = %w[exclusive special].flat_map do |tier|
      [1, 3, 6, 12].map { |months| subscription(tier, months) }
    end
    products << subscription("exclusive", 24)

    first = menu.category(products: products, mode: "b", anchor_sku: "0x1_exclusive_1m")
    second = menu.category(products: products, mode: "b", anchor_sku: "0x1_exclusive_24m")
    assert_equal 8, first.reply_markup.fetch(:inline_keyboard).flatten.count { |b| b.fetch(:callback_data).start_with?("v:") }
    assert_equal "c:b:0x1_exclusive_24m", first.reply_markup.dig(:inline_keyboard, -1, 2, :callback_data)
    assert_equal "c:b:0x1_exclusive_1m", second.reply_markup.dig(:inline_keyboard, -1, 0, :callback_data)
  end

  private

  def subscription(tier, months)
    {
      "id" => "0x1_#{tier}_#{months}m",
      "attributes" => {
        "name" => "#{tier} #{months}",
        "button_label" => "#{tier.capitalize} #{months}m",
        "metadata" => { "family" => "0x1_subscription", "tier" => tier, "duration_months" => months },
        "position" => 50 + months,
        "status" => "inactive",
        "preview" => true
      }
    }
  end

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
