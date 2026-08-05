# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_pinned_marketplace_modules
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes source, 'WEBAPP_CORE_REVISION = "6f8632de183e362bf62cfb9b6161ccb0f1298413"'
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
  end

  def test_keyboard_confirmation_replaces_fixed_workspace_navigation
    styles = File.read(File.join(ROOT, "webapp/styles.css"))

    assert_match(
      /body:has\(\.keyboard-confirm:not\(\[hidden\]\)\) \.workspace-navigation \{\s*visibility: hidden;\s*pointer-events: none;\s*\}/m,
      styles
    )
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
end
