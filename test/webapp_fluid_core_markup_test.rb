# frozen_string_literal: true

require "minitest/autorun"

class WebappFluidCoreMarkupTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_pins_the_merged_core_markup_revision
    app = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes app, 'const WEBAPP_CORE_REVISION = "707f9c122548efaf72c00be04bac6e6f1cc187ba"'
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
end
