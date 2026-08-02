import { createTelegramHost } from "./adapter/telegram-host.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const WEBAPP_CORE_REVISION = "ad42eaefbb1b8ce5bf27e65404f64f3ce0317840";
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
  const context = app.context();
  const marketRoot = document.querySelector("main");
  const broker = await webappCore.mountBrokerWorkspace({ document, transport, ...app.context() });
  if (broker?.root) document.body.append(broker.root);
  const admin = webappCore.mountAdminWorkspace({ document, container: document.body, ...context });
  const sections = [
    { id: "market", label: "Market", root: marketRoot },
    { id: "listings", label: "Listings", root: broker?.root },
    { id: "admin", label: "Admin", root: admin?.root }
  ].filter((entry) => entry.root);

  if (sections.length > 1) {
    webappCore.mountWorkspaceNavigation({
      document,
      session: context.session,
      sections,
      selectionFeedback: () => host.selectionFeedback()
    });
    document.body.classList.add("has-workspace-navigation");
  }
}

start().catch((error) => {
  const status = document.querySelector("#status");
  if (status) {
    status.textContent = error.message;
    status.dataset.error = "true";
  }
});
