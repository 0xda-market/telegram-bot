import { applyDaypart, observeDaypart } from "./adapter/daypart.js";
import { pickTelegramRecipient } from "./adapter/recipient-picker.js";
import { createRecipientPickerTransport } from "./adapter/recipient-picker-transport.js";
import { createTelegramHost } from "./adapter/telegram-host.js";
import { localizeTelegramShell } from "./adapter/shell-localization.js";
import { createStartupController } from "./adapter/startup-controller.js";
import { createTelegramTransport } from "./adapter/telegram-transport.js";

const WEBAPP_CORE_REVISION = "646fac4dcab7c77127d209e1efd05ebe672a1e38";
const runtime = globalThis.__ZERO_X_DA_MARKET__ || {};
const webappCoreModuleUrl = runtime.webappCoreModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/index.js`;
const brokerOrdersModuleUrl = runtime.brokerOrdersModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/broker-orders.js`;
const checkoutFeedbackModuleUrl = runtime.checkoutFeedbackModuleUrl ||
  `https://cdn.jsdelivr.net/gh/0xda-market/webapp-core@${WEBAPP_CORE_REVISION}/src/checkout-feedback-state.js`;
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

function showSpecialAccount(account, locale) {
  const section = document.getElementById("special-account");
  const uk = /^uk/i.test(locale);
  const status = document.createElement("p");
  section.replaceChildren(status);
  section.hidden = false;
  const addLink = (title, href) => {
    const a = document.createElement("a");
    a.textContent = title;
    a.href = href;
    section.append(a, document.createElement("br"));
  };
  if (account.state === "linked") {
    status.textContent = `${account.bond} · ${account.seeds} seeds · ${account.held ? (uk ? "Special уже є" : "Special already held") : "Special"}`;
    if (account.purchase_open && !account.held) {
      for (const months of [1, 3, 6, 12]) {
        addLink(uk ? `Special на ${months} міс. · у чаті` : `Special · ${months} months · in chat`,
          `https://t.me/zeroxda_market_test_bot?start=0x1_special_${months}m`);
      }
    }
  } else if (account.state === "sign_in_required") {
    status.textContent = account.link_refusal === "provider_type_already_linked"
      ? (uk ? "До Bond уже прив’язаний інший Telegram." : "This Bond already has another Telegram account.")
      : (uk ? "Прив’яжи Telegram до свого Bond." : "Connect Telegram to your Bond.");
    if (typeof account.link_url === "string" && /^https:\/\//i.test(account.link_url)) {
      addLink(uk ? "Авторизуватися у 0x1" : "Sign in to 0x1", account.link_url);
    }
  } else {
    status.textContent = uk ? "Баланс і статус Special тимчасово недоступні." : "Wallet and Special status temporarily unavailable.";
  }
}

async function initializeApplication({ host, transport }) {
  const [webappCore, brokerOrdersModule] = await Promise.all([
    import(webappCoreModuleUrl),
    import(brokerOrdersModuleUrl)
  ]);
  const app = await webappCore.mountMarketApp({ host, transport, document });
  const context = app.context();
  const marketRoot = document.querySelector("main");
  const bootstrap = await transport.bootstrap({ locale: context.locale });
  const account = bootstrap.meta?.session?.special_account;
  if (account) showSpecialAccount(account, context.locale);
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
  const trading = context.session?.paper_trading_enabled
    ? webappCore.mountTradingWorkspace({ document, transport, locale: context.locale })
    : null;
  if (trading?.root) document.body.append(trading.root);
  const sections = [
    { id: "market", root: marketRoot },
    { id: "trading", root: trading?.root },
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
  let host = createTelegramHost(telegram);
  const locale = host.locale();
  const checkoutDialog = document.querySelector("#checkout-dialog");
  const { createCheckoutFeedbackState, withCheckoutFeedback } = await import(checkoutFeedbackModuleUrl);
  const checkoutFeedback = createCheckoutFeedbackState({ dialog: checkoutDialog });
  const transport = withCheckoutFeedback(
    createTelegramTransport({ telegram, apiBaseUrl, locale }),
    { dialog: checkoutDialog, feedback: checkoutFeedback }
  );
  const recipientTransport = createRecipientPickerTransport({ telegram, apiBaseUrl });
  host = createTelegramHost(telegram, {
    recipientPicker: () => pickTelegramRecipient({ telegram, transport: recipientTransport, locale })
  });

  host.initialize();
  applyDaypart(document, { override: runtime.daypart });
  observeDaypart(document, { override: runtime.daypart });
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
