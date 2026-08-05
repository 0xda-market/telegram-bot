# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_pinned_marketplace_modules
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes source, 'WEBAPP_CORE_REVISION = "707f9c122548efaf72c00be04bac6e6f1cc187ba"'
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js"
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/broker-orders.js"
    assert_includes source, "mountBrokerWorkspace({ document, transport, ...context })"
    assert_includes source, "mountBrokerOrders({"
    assert_includes source, "mountAdminWorkspace({"
    assert_includes source, "mountWorkspaceNavigation({"
    refute_includes source, "webapp-core@master"

    styles = File.read(File.join(ROOT, "webapp/styles.css"))
    assert_includes styles, 'input[type="number"]'
    assert_includes styles, ".keyboard-confirm"

    html = File.read(File.join(ROOT, "webapp/index.html"))
    assert_includes html, "data-mobile-input-confirm"
    assert_includes html, 'href="./fluid-controls.css"'
  end

  def test_fluid_bar_keeps_keyboard_confirmation_clear_of_workspace_navigation
    styles = File.read(File.join(ROOT, "webapp/fluid-controls.css"))

    assert_includes styles, "--fluid-bar-surface"
    assert_includes styles, "backdrop-filter: blur(26px) saturate(145%)"
    assert_includes styles, '.workspace-tab[aria-selected="true"]'
    assert_match(
      /body:has\(\.keyboard-confirm:not\(\[hidden\]\)\) \.workspace-navigation \{[\s\S]*visibility: hidden;[\s\S]*pointer-events: none;/,
      styles
    )
  end

  def test_design_tokens_own_every_measurable_target
    tokens = File.read(File.join(ROOT, "webapp/design-tokens.css"))
    html = File.read(File.join(ROOT, "webapp/index.html"))

    assert_includes html, 'href="./design-tokens.css"'
    assert_operator html.index("design-tokens.css"), :<, html.index("styles.css")
    assert_includes tokens, "color-scheme: dark"
    assert_includes tokens, "--surface-base"
    assert_includes tokens, "--target-min: 44px"
    assert_includes tokens, "--focus-ring"
    assert_includes tokens, "--ease-viscous"
    # The base surface is brand-owned; only the accent derives from the theme.
    assert_includes tokens, "--accent: var(--tg-theme-button-color"
    refute_match(/--surface-\w+:\s*var\(--tg-theme/, tokens)
  end

  def test_one_lens_travels_instead_of_filling_each_tab
    fluid = File.read(File.join(ROOT, "webapp/fluid-controls.css"))

    assert_includes fluid, ".workspace-navigation::after"
    assert_includes fluid, "transform: translateX(calc(var(--lens-index) * 100%))"
    assert_includes fluid, '.workspace-navigation:has(.workspace-tab:nth-child(2)[aria-selected="true"])'

    selected = fluid[/\.workspace-tab\[aria-selected="true"\]\s*\{([^}]*)\}/, 1]

    refute_nil selected
    refute_match(/background/, selected)
  end

  def test_material_backgrounds_survive_a_missing_color_mix
    fluid = File.read(File.join(ROOT, "webapp/fluid-controls.css"))

    %w[--fluid-bar-fallback --fluid-lens-fallback].each do |token|
      assert_match(/#{token}:\s*#[0-9a-f]{6}/, fluid)
    end

    [".workspace-navigation,\n.keyboard-confirm", ".workspace-navigation::after"].each do |selector|
      declarations = fluid[/#{Regexp.escape(selector)}\s*\{([^}]*)\}/, 1]

      refute_nil declarations, "expected a top-level rule for #{selector}"
      backgrounds = declarations.scan(/background:\s*[^;]+/)

      refute_empty backgrounds, "#{selector} must declare a background"
      assert_match(/var\(--fluid-\w+-fallback\)/, backgrounds.first,
                   "#{selector} must declare its opaque background before any color-mix()")
    end

    assert_includes fluid, "@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px)))"
  end

  def test_shell_uses_host_viewport_units_and_visible_focus
    styles = File.read(File.join(ROOT, "webapp/styles.css"))

    assert_includes styles, ":focus-visible"
    assert_includes styles, "outline: var(--focus-ring-width) solid var(--focus-ring)"
    assert_includes styles, "font-variant-numeric: tabular-nums"

    %w[styles.css bootstrap.css].each do |file|
      css = File.read(File.join(ROOT, "webapp", file))
      next unless css.include?("100vh")

      assert_includes css, "var(--tg-viewport-stable-height, 100dvh)",
                      "#{file} uses 100vh without the Telegram viewport height"
    end
  end

  def test_previously_sub_target_controls_use_the_minimum_target
    styles = File.read(File.join(ROOT, "webapp/styles.css"))
    products = File.read(File.join(ROOT, "webapp/admin-products.css"))

    close = styles[/\.dialog-close\s*\{([^}]*)\}/, 1]

    refute_nil close
    assert_includes close, "width: var(--target-min)"
    assert_includes close, "height: var(--target-min)"
    assert_includes products, "min-height: var(--target-min)"
    refute_match(/min-height:\s*3\dpx/, products)
  end

  def test_layout_and_material_never_declare_the_same_property
    layout = top_level_declarations(File.read(File.join(ROOT, "webapp/styles.css")))
    material = top_level_declarations(File.read(File.join(ROOT, "webapp/fluid-controls.css")))

    conflicts = layout.filter_map do |selector, properties|
      shared = properties & material.fetch(selector, [])
      "#{selector} -> #{shared.join(', ')}" unless shared.empty?
    end

    assert_empty conflicts,
                 "styles.css owns layout and fluid-controls.css owns material; " \
                 "these selectors declare the same property in both files"
  end

  def test_telegram_specifics_stay_in_adapter
    transport = File.read(File.join(ROOT, "webapp/adapter/telegram-transport.js"))
    shell_localization = File.read(File.join(ROOT, "webapp/adapter/shell-localization.js"))

    assert_includes transport, '"x-telegram-init-data"'
    assert_includes transport, "telegram?.initData"
    assert_includes transport, "listBrokerOrders"
    assert_includes transport, "acceptBrokerOrder"
    assert_includes transport, "completeBrokerOrder"
    refute_includes transport, "actor_user_id"
    assert_includes shell_localization, "Завантаження товарів…"
    assert_includes shell_localization, "Підтвердити"
  end

  private

  # Collects the properties each selector declares outside any at-rule, so a
  # responsive override inside @media stays a legitimate override.
  def top_level_declarations(css)
    declarations = Hash.new { |rules, selector| rules[selector] = [] }
    buffer = +""
    block = nil
    depth = 0

    css.gsub(%r{/\*.*?\*/}m, "").each_char do |character|
      case character
      when "{"
        depth += 1
        depth == 1 ? (block = buffer.strip; buffer = +"") : buffer << character
      when "}"
        depth -= 1
        if depth.zero?
          record_declarations(declarations, block, buffer) unless block.start_with?("@")
          block = nil
          buffer = +""
        else
          buffer << character
        end
      else
        buffer << character
      end
    end

    declarations
  end

  def record_declarations(declarations, block, body)
    properties = body.split(";").filter_map do |declaration|
      name = declaration.split(":", 2).first.to_s.strip
      name unless name.empty?
    end

    block.split(",").each { |selector| declarations[selector.strip].concat(properties) }
  end
end
