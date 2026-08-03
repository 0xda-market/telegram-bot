import { createTelegramHost } from "./adapter/telegram-host.js";
import { localizeTelegramShell } from "./adapter/shell-localization.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const WEBAPP_CORE_REVISION = "0ebe26fa0e85cd9822a303f6e2043e372fb75b0e";
const runtime = globalThis.__ZERO_X_DA_MARKET__ || {};
const webappCoreModuleUrl = runtime.webappCoreModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js`;
const apiBaseUrl = runtime.apiBaseUrl || ".";

async function start() {
  const telegram = globalThis.Telegram?.WebApp;
  const host = createTelegramHost(telegram);
  const locale = host.locale();
  const transport = createTelegramTransport({ telegram, apiBaseUrl });

  host.initialize();
  localizeTelegramShell(document, locale);
  const webappCore = await import(webappCoreModuleUrl);
  const app = await webappCore.mountMarketApp({ host, transport, document });
  const context = app.context();
  const marketRoot = document.querySelector("main");
  const broker = await webappCore.mountBrokerWorkspace({ document, transport, ...context });
  if (broker?.root) document.body.append(broker.root);
  const admin = webappCore.mountAdminWorkspace({
    document,
    container: document.body,
    transport,
    ...context
  });
  await admin?.ready;
  const sections = [
    { id: "market", root: marketRoot },
    { id: "listings", root: broker?.root },
    { id: "admin", root: admin?.root }
  ].filter((entry) => entry.root);

  if (sections.length > 1) {
    webappCore.mountWorkspaceNavigation({
      document,
      locale: context.locale,
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
