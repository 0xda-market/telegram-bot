import { createTelegramHost } from "./adapter/telegram-host.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const runtime = globalThis.__ZERO_X_DA_MARKET__ || {};
const webAppModuleUrl = runtime.webAppModuleUrl || "/web-app/index.js";
const webAppCoreUrl = runtime.webAppCoreUrl || "/webapp-core/index.js";
const apiBaseUrl = runtime.apiBaseUrl || ".";

async function start() {
  const telegram = globalThis.Telegram?.WebApp;
  const host = createTelegramHost(telegram);
  const transport = createTelegramTransport({ telegram, apiBaseUrl });
  const [{ mountMarketApp }, engine] = await Promise.all([
    import(webAppModuleUrl),
    import(webAppCoreUrl)
  ]);

  host.initialize();
  await mountMarketApp({ host, transport, engine, document });
}

start().catch((error) => {
  const status = document.querySelector("#status");
  if (status) {
    status.textContent = error.message;
    status.dataset.error = "true";
  }
});
