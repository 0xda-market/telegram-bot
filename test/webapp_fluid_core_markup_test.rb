# frozen_string_literal: true

require "minitest/autorun"

class WebappFluidCoreMarkupTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_pins_the_merged_core_markup_revision
    app = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes app, 'const WEBAPP_CORE_REVISION = "f588cdf71f5c12c93851638ca88e5c904a34bca6"'
  end

  def test_loads_adapter_styles_after_the_fluid_material
    html = File.read(File.join(ROOT, "webapp/index.html"))

    assert_includes html, 'href="./fluid-core-markup.css"'
    assert_operator html.index("fluid-controls.css"), :<, html.index("fluid-core-markup.css")
  end

  def test_narrow_navigation_uses_icons_without_losing_the_accessible_label
    css = File.read(File.join(ROOT, "webapp/fluid-core-markup.css"))

    assert_includes css, ".workspace-tab-icon"
    assert_includes css, ".workspace-tab-label"
    assert_includes css, "@media (max-width: 430px)"
    assert_includes css, "clip: rect(0 0 0 0)"
    refute_match(/display:\s*none/, css[/@media \(max-width: 430px\)(.*?)(?=@media|\z)/m, 1])
  end

  def test_admin_overview_is_a_compact_scrollable_rail
    css = File.read(File.join(ROOT, "webapp/fluid-core-markup.css"))

    assert_includes css, ".admin-capability-rail"
    assert_includes css, "overflow-x: auto"
    assert_includes css, "scroll-snap-type: inline proximity"
    assert_includes css, ".admin-capability-summary"
  end

  def test_capability_link_is_secondary_navigation
    link = core_markup[/\.admin-capability-link\s*\{([^}]*)\}/, 1]

    refute_nil link
    assert_includes link, "min-height: var(--target-min)"
    assert_includes link, "var(--edge-control)"
    refute_match(/background:\s*var\(--accent\)/, link)
  end

  def test_changed_price_rows_are_accented_rather_than_flooded
    changed = core_markup[/\.admin-price-row\[data-price-state="changed"\]\s*\{([^}]*)\}/, 1]

    refute_nil changed
    assert_match(/box-shadow:\s*inset/, changed)
    refute_match(/^\s*background:/, changed)
    assert_includes core_markup, ".admin-price-amount-value"
    assert_includes core_markup, ".admin-price-change"
  end

  def test_selected_product_summary_reads_before_the_editable_fields
    assert_includes core_markup, ".admin-product-summary"
    assert_includes core_markup, ".admin-product-summary-fields"
    assert_includes core_markup, '.admin-product-summary-field[data-product-field="localizations"]'
    # The product select moved inside the core-owned selector wrapper.
    products = File.read(File.join(ROOT, "webapp/admin-products.css"))

    assert_includes products, ".admin-product-selector select"
    refute_includes products, ".admin-products > select"
  end

  def test_inventory_balances_read_as_one_server_owned_group
    inventory = core_markup[/\.broker-listing-inventory\s*\{([^}]*)\}/, 1]

    refute_nil inventory
    assert_includes inventory, "grid-template-columns: repeat(4, minmax(0, 1fr))"
    assert_includes inventory, "background: var(--surface-recessed)"
    assert_includes core_markup, ".broker-listing-balance-value"
  end

  def test_withdrawing_a_listing_is_not_the_primary_accent
    withdraw = core_markup[/\.broker-listing-action\[data-listing-action="withdraw"\]\s*\{([^}]*)\}/, 1]

    refute_nil withdraw
    assert_includes withdraw, "var(--semantic-danger)"
    refute_match(/background:\s*var\(--accent\)/, withdraw)
    # The restrained edge is declared plainly before any color-mix().
    assert_match(/border:\s*1px solid var\(--edge-control\)/, withdraw)
  end

  def test_order_lifecycle_rail_keeps_every_step_and_never_relies_on_colour_alone
    assert_includes core_markup, ".order-lifecycle-rail"
    assert_includes core_markup, ".order-lifecycle-step::after"
    assert_includes core_markup, ".order-lifecycle-step:last-child::after"

    %w[complete current failed].each do |state|
      assert_includes core_markup, %(.order-lifecycle-step[data-lifecycle-state="#{state}"]::before)
      assert_includes core_markup,
                      %(.order-lifecycle-step[data-lifecycle-state="#{state}"] .order-lifecycle-step-label),
                      "#{state} steps must carry a labelled treatment, not a marker tone alone"
    end
  end

  private

  def core_markup
    @core_markup ||= File.read(File.join(ROOT, "webapp/fluid-core-markup.css"))
  end
end
