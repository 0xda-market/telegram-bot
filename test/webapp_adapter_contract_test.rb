# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_pinned_marketplace_modules
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes source, 'WEBAPP_CORE_REVISION = "76fb0aa7da358b0ecc133e03bac7211b34c4f2fd"'
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js"
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/broker-orders.js"
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/checkout-feedback-state.js"
    assert_includes source, "createCheckoutFeedbackState"
    assert_includes source, "withCheckoutFeedback"
    assert_includes source, "pickTelegramRecipient"
    assert_includes source, "createRecipientPickerTransport"
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
    assert_includes html, 'href="./orb-controls.css"'
    assert_includes html, 'href="./fluid-controls.css"'
    assert_includes html, 'href="./recipient-picker.css"'
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
    assert_includes tokens, "--accent-source: var(--tg-theme-button-color"
    refute_match(/--surface-\w+:\s*var\(--tg-theme/, tokens)
  end

  MODULATED_TOKENS = %w[--edge-highlight --edge-shadow --accent-glow --accent].freeze

  def test_daypart_modulates_intensity_and_never_a_contrast_contract
    tokens = File.read(File.join(ROOT, "webapp/design-tokens.css"))
    states = tokens.scan(/:root\[data-daypart="(\w+)"\]\s*\{([^}]*)\}/)

    assert_equal %w[night twilight], states.map(&:first).uniq.sort,
                 "day is the base :root state and needs no override"

    states.each do |daypart, body|
      declared = body.split(";").filter_map do |declaration|
        name = declaration.split(":", 2).first.to_s.strip
        name unless name.empty?
      end

      assert_empty declared - MODULATED_TOKENS,
                   "daypart #{daypart} may only modulate #{MODULATED_TOKENS.join(', ')}"
    end
  end

  def test_daypart_accent_tint_cannot_invalidate_a_material_background
    tokens = File.read(File.join(ROOT, "webapp/design-tokens.css"))
    guard = "@supports (color: color-mix(in srgb, #000 50%, #fff))"

    assert_includes tokens, guard

    guarded = tokens[/#{Regexp.escape(guard)}\s*\{.*/m]
    unguarded = tokens.sub(/#{Regexp.escape(guard)}\s*\{.*/m, "")

    assert_match(/--accent:\s*color-mix/, guarded)
    refute_match(/:root\[data-daypart="\w+"\]\s*\{[^}]*--accent:\s*color-mix/m, unguarded)
    assert_match(/--accent:\s*var\(--accent-source\)/, unguarded)
  end

  def test_interactive_boundaries_use_the_control_edge
    tokens = File.read(File.join(ROOT, "webapp/design-tokens.css"))

    assert_includes tokens, "--edge-control"
    refute_match(/:root\[data-daypart="\w+"\]\s*\{[^}]*--edge-control/m, tokens)

    %w[styles.css admin-prices.css admin-products.css recipient-picker.css].each do |file|
      css = File.read(File.join(ROOT, "webapp", file))
      inputs = css.scan(/^[^{}]*\binput[^{}]*\{[^}]*\}/m)

      next if inputs.empty?

      assert inputs.any? { |rule| rule.include?("var(--edge-control)") },
             "#{file} styles inputs without the identifying control boundary"
    end
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

  def test_close_and_progress_orbs_share_one_visual_contract
    tokens = File.read(File.join(ROOT, "webapp/design-tokens.css"))
    bootstrap = File.read(File.join(ROOT, "webapp/bootstrap.css"))
    styles = File.read(File.join(ROOT, "webapp/styles.css"))
    orbs = File.read(File.join(ROOT, "webapp/orb-controls.css"))

    %w[--orb-size --orb-stroke --orb-track --orb-surface --orb-spin-duration].each do |token|
      assert_includes tokens, token
    end

    assert_includes orbs, ".bootstrap-spinner"
    assert_includes orbs, '[data-loading="true"]::after'
    assert_includes orbs, ".dialog-close::before"
    assert_includes orbs, 'dialog[data-loading="true"]::after'
    assert_includes orbs, "content: none"
    assert_includes orbs, 'dialog[data-checkout-feedback="loading"] .dialog-close::before'
    assert_includes orbs, 'dialog[data-checkout-feedback="error"] .dialog-close::before'
    assert_includes orbs, 'dialog[data-checkout-feedback="error"] .dialog-close::after'
    assert_includes orbs, "animation: orb-close-pulse"
    refute_includes bootstrap, ".bootstrap-spinner"
    refute_includes styles, '[data-loading="true"]::after'
    refute_match(/border-radius:\s*50%/, bootstrap + styles + orbs)
  end

  STYLESHEET_OWNERS = {
    "styles.css" => "layout",
    "orb-controls.css" => "circular controls and progress",
    "fluid-controls.css" => "material",
    "fluid-core-markup.css" => "core-owned elements",
    "recipient-picker.css" => "recipient picker presentation"
  }.freeze

  def test_no_two_adapter_stylesheets_declare_the_same_property
    declarations = STYLESHEET_OWNERS.keys.to_h do |file|
      [file, top_level_declarations(File.read(File.join(ROOT, "webapp", file)))]
    end

    conflicts = declarations.keys.combination(2).flat_map do |left, right|
      declarations[left].filter_map do |selector, properties|
        shared = properties & declarations[right].fetch(selector, [])
        next if shared.empty?

        "#{selector} -> #{shared.join(', ')} " \
          "(#{left} owns #{STYLESHEET_OWNERS[left]}, #{right} owns #{STYLESHEET_OWNERS[right]})"
      end
    end

    assert_empty conflicts, "these selectors declare the same property in two adapter stylesheets"
  end

  def test_telegram_specifics_stay_in_adapter
    transport = File.read(File.join(ROOT, "webapp/adapter/telegram-transport.js"))
    recipient = File.read(File.join(ROOT, "webapp/adapter/recipient-picker.js"))
    recipient_transport = File.read(File.join(ROOT, "webapp/adapter/recipient-picker-transport.js"))
    shell_localization = File.read(File.join(ROOT, "webapp/adapter/shell-localization.js"))

    assert_includes transport, '"x-telegram-init-data"'
    assert_includes transport, "telegram?.initData"
    assert_includes transport, "listBrokerOrders"
    assert_includes transport, "acceptBrokerOrder"
    assert_includes transport, "completeBrokerOrder"
    refute_includes transport, "actor_user_id"
    assert_includes recipient, "telegram.requestChat"
    assert_includes recipient_transport, '"x-telegram-init-data"'
    assert_includes shell_localization, "Завантаження товарів…"
    assert_includes shell_localization, "Підтвердити"
  end

  private

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
