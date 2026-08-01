# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_one_pinned_webapp_core_module
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_match(/WEBAPP_CORE_REVISION = "[0-9a-f]{40}"/, source)
    assert_includes source, "0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js"
    assert_includes source, "mountMarketApp({ host, transport, document })"
    assert_includes source, "mountBrokerWorkspace({ document, ...app.context() })"
    refute_includes source, "/web-app/index.js"
    refute_includes source, "new CheckoutController"
    refute_includes source, "new CatalogStore"
  end

  def test_telegram_specifics_stay_in_adapter
    host = File.read(File.join(ROOT, "webapp/adapter/telegram-host.js"))
    transport = File.read(File.join(ROOT, "webapp/adapter/telegram-transport.js"))

    assert_includes host, "Telegram"
    assert_includes transport, '"x-telegram-init-data"'
    assert_includes transport, "telegram?.initData"
  end
end
