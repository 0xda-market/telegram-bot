# frozen_string_literal: true

require "minitest/autorun"

class WebAppAdapterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_entrypoint_delegates_to_shared_web_app
    source = File.read(File.join(ROOT, "webapp/app.js"))

    assert_includes source, 'import(webAppModuleUrl)'
    assert_includes source, "mountMarketApp({ host, transport, engine, document })"
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
