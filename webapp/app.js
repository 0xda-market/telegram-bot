import { createTelegramHost } from "./adapter/telegram-host.js";
import { localizeTelegramShell } from "./adapter/shell-localization.js";
import { createStartupController } from "./adapter/startup-controller.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const WEBAPP_CORE_REVISION = "707f9c122548efaf72c00be04bac6e6f1cc187ba";
const runtime = globalThis.__ZERO_X_DA_MARKET__ || {};
const webappCoreModuleUrl = runtime.webappCoreModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js`;
const brokerOrdersModuleUrl = runtime.brokerOrdersModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/broker-orders.js`;
const apiBaseUrl = runtime.apiBaseUrl || ".";

function revealApplication() {
  document.body.classList.remove("app-booting");
  document.body.removeAttribute("aria-busy");
}

function shellMessage(message, error = false) {
  const node = document.querySelector("#bootstrap-shell p");
  if (node) {
    node.textContent = message;
    node.dataset.error = error ? "true" : "false";
  }
}

function logStartup(event) {
  const payload = {
    component: "telegram-mini-app",
    timestamp: new Date().toISOString(),
    ...event,
    error: event.error?.message
  };
  console.info("[0xda-market startup]", payload);
}

async function initializeApplication({ host, transport }) {
  const [webappCore, brokerOrdersModule] = await Promise.all([
    import(webappCoreModuleUrl),
    import(brokerOrdersModuleUrl)
  ]);
  const app = await webappCore.mountMarketApp({ host, transport, document });
  const context = app.context();
  const marketRoot = document.querySelector("main");
  const broker = await webappCore.mountBrokerWorkspace({ document, transport, ...context });
  if (broker?.root) document.body.append(broker.root);
  const brokerOrders = await brokerOrdersModule.mountBrokerOrders({
    document,
    container: broker?.root || document.body,
    transport,
    ...context
  });
  const admin = webappCore.mountAdminWorkspace({ document, container: document.body, transport, ...context });
  await admin?.ready;
  const sections = [
    { id: "market", root: marketRoot },
    { id: "listings", root: broker?.root || brokerOrders?.root },
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

async function start() {
  const telegram = globalThis.Telegram?.WebApp;
  const host = createTelegramHost(telegram);
  const locale = host.locale();
  const transport = createTelegramTransport({ telegram, apiBaseUrl });

  host.initialize();
  localizeTelegramShell(document, locale);
  shellMessage(locale.startsWith("uk") ? "Завантаження маркету…" : "Loading market…");

  const startup = createStartupController({
    run: () => initializeApplication({ host, transport }),
    onPhase: (event) => {
      logStartup(event);
      if (event.phase === "retry") {
        shellMessage(locale.startsWith("uk") ? "Повторне підключення…" : "Reconnecting…");
      }
    },
    onFailure: async (error) => {
      shellMessage(
        locale.startsWith("uk") ? "Не вдалося завантажити. Відкрийте застосунок ще раз." : "Could not load. Reopen the app.",
        true
      );
      await transport.reportRuntimeEvent?.({
        type: "startup_failed",
        message: error?.message || "unknown startup failure",
        revision: WEBAPP_CORE_REVISION
      }).catch(() => {});
    }
  });

  await startup.start();
  revealApplication();
}

start().catch((error) => {
  logStartup({ phase: "failed", error });
  // Deliberately keep the atomic loading shell visible. A partially mounted
  // market is never presented as a usable application.
});
