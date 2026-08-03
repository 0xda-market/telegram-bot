# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_one_pinned_localized_webapp_core_module
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes source, 'WEBAPP_CORE_REVISION = "13fc73578d572f93d0c8b4ef2f7f0f3693009e9c"'
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js"
    assert_includes source, "localizeTelegramShell(document, locale)"
    assert_includes source, "mountMarketApp({ host, transport, document })"
    assert_includes source, "const context = app.context()"
    assert_includes source, "mountBrokerWorkspace({ document, transport, ...context })"
    assert_includes source, "mountAdminWorkspace({"
    assert_includes source, "mountWorkspaceNavigation({"
    assert_includes source, "locale: context.locale"
    refute_includes source, "webapp-core@master"
    refute_includes source, "/web-app/index.js"
    refute_includes source, "new CheckoutController"
    refute_includes source, "new CatalogStore"
  end

  def test_telegram_specifics_stay_in_adapter
    host = File.read(File.join(ROOT, "webapp/adapter/telegram-host.js"))
    transport = File.read(File.join(ROOT, "webapp/adapter/telegram-transport.js"))
    shell_localization = File.read(File.join(ROOT, "webapp/adapter/shell-localization.js"))

    assert_includes host, "Telegram"
    assert_includes transport, '"x-telegram-init-data"'
    assert_includes transport, "telegram?.initData"
    assert_includes shell_localization, "Завантаження товарів…"
    assert_includes shell_localization, "Отримати ціну"
  end
end
