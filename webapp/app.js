import { createTelegramHost } from "./adapter/telegram-host.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const WEBAPP_CORE_REVISION = "fbcdd408cb26903bb641740e7e1b82d802351422";
const runtime = globalThis.__ZERO_X_DA_MARKET__ || {};
const webappCoreModuleUrl = runtime.webappCoreModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js`;
const apiBaseUrl = runtime.apiBaseUrl || ".";

async function start() {
  const telegram = globalThis.Telegram?.WebApp;
  const host = createTelegramHost(telegram);
  const transport = createTelegramTransport({ telegram, apiBaseUrl });
  const webappCore = await import(webappCoreModuleUrl);

  host.initialize();
  const app = await webappCore.mountMarketApp({ host, transport, document });
  webappCore.mountBrokerWorkspace({ document, ...app.context() });
}

start().catch((error) => {
  const status = document.querySelector("#status");
  if (status) {
    status.textContent = error.message;
    status.dataset.error = "true";
  }
});
