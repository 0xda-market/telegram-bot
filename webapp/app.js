import {
  CatalogStore,
  CheckoutController,
  createCatalogSnapshot,
  formatPrice,
  pageSizeForViewport
} from "/webapp-core/index.js";

const telegram = window.Telegram?.WebApp;
const elements = {
  action: document.querySelector("#checkout-action"),
  category: document.querySelector("#category"),
  closeDialog: document.querySelector("#close-dialog"),
  dialog: document.querySelector("#checkout-dialog"),
  dialogCategory: document.querySelector("#dialog-category"),
  dialogName: document.querySelector("#dialog-name"),
  dialogPrice: document.querySelector("#dialog-price"),
  dialogStatus: document.querySelector("#dialog-status"),
  home: document.querySelector("#home"),
  next: document.querySelector("#next"),
  previous: document.querySelector("#previous"),
  products: document.querySelector("#products"),
  search: document.querySelector("#search"),
  snapshot: document.querySelector("#snapshot"),
  status: document.querySelector("#status")
};

let catalogRequests = 0;
let store;
let selectedProduct;

const checkout = new CheckoutController({
  async quote(sku) {
    return api("./quotes", {
      method: "POST",
      body: JSON.stringify({ sku, locale: locale() })
    }).then((document) => document.data);
  },
  async accept(quoteId) {
    return api(`./quotes/${encodeURIComponent(quoteId)}/accept`, {
      method: "POST",
      body: "{}"
    }).then((document) => document.data);
  },
  async refresh(orderId) {
    return api(`./orders/${encodeURIComponent(orderId)}`).then((document) => document.data);
  }
});

function locale() {
  const language = telegram?.initDataUnsafe?.user?.language_code || navigator.language || "en";
  const code = String(language).toLowerCase().split(/[-_]/, 1)[0];
  return ({ en: "en_US", uk: "uk_UA", ru: "ru_RU", fr: "fr_FR", es: "es_ES", de: "de_DE" })[code] || "en_US";
}

async function api(path, options = {}) {
  const initData = telegram?.initData || "";
  if (!initData) throw new Error("Open this Mini App inside Telegram.");

  const response = await fetch(path, {
    ...options,
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-telegram-init-data": initData,
      ...(options.headers || {})
    }
  });
  const document = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(document.message || document.error || `HTTP ${response.status}`);
  return document;
}

async function loadCatalogOnce() {
  catalogRequests += 1;
  if (catalogRequests > 1) throw new Error("The complete catalog may only be loaded once per Mini App session.");

  return api(`./bootstrap?${new URLSearchParams({ locale: locale() })}`).then(createCatalogSnapshot);
}

function viewportPageSize() {
  return pageSizeForViewport({
    width: window.innerWidth,
    height: telegram?.viewportStableHeight || window.innerHeight
  });
}

function renderCategories(snapshot) {
  for (const category of snapshot.categories) {
    const option = document.createElement("option");
    option.value = category.id;
    option.textContent = category.label;
    elements.category.append(option);
  }
}

function renderCatalog() {
  const view = store.view();
  elements.products.replaceChildren(...view.products.map(productCard));
  elements.previous.disabled = !view.hasPrevious;
  elements.next.disabled = !view.hasNext;
  elements.status.textContent = `${view.totalProducts} products · ${view.page}/${view.pageCount}`;
}

function productCard(product) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "product";

  const category = document.createElement("span");
  category.className = "product-category";
  category.textContent = product.category.label;

  const name = document.createElement("strong");
  name.textContent = product.attributes.button_label || product.attributes.name;

  const price = document.createElement("span");
  price.className = "product-price";
  price.textContent = formatPrice(product) || "Unavailable";

  button.append(category, name, price);
  button.disabled = !product.attributes.price;
  button.addEventListener("click", () => openCheckout(product));
  return button;
}

function openCheckout(product) {
  selectedProduct = product;
  checkout.reset(product);
  elements.dialogCategory.textContent = product.category.label;
  elements.dialogName.textContent = product.attributes.name;
  elements.dialogPrice.textContent = formatPrice(product) || "Unavailable";
  renderCheckout();
  elements.dialog.showModal();
  telegram?.HapticFeedback?.selectionChanged();
}

async function performCheckoutAction() {
  const status = checkout.state.status;
  let operation;

  if (["idle", "failed", "succeeded"].includes(status)) {
    operation = checkout.quote(selectedProduct);
  } else if (status === "quoted") {
    operation = checkout.accept();
  } else if (["pending", "accepted"].includes(status)) {
    operation = checkout.refresh();
  } else {
    return;
  }

  renderCheckout();
  await operation;
  renderCheckout();
}

function renderCheckout() {
  const state = checkout.state;
  elements.action.disabled = false;

  switch (state.status) {
    case "quoting":
      elements.dialogStatus.textContent = "Requesting current quote…";
      elements.action.disabled = true;
      break;
    case "quoted": {
      const expiresAt = state.quote.attributes.expires_at;
      elements.dialogStatus.textContent = `Quote expires ${new Date(expiresAt).toLocaleTimeString()}.`;
      elements.action.textContent = "Confirm purchase";
      telegram?.HapticFeedback?.notificationOccurred("success");
      break;
    }
    case "accepting":
      elements.dialogStatus.textContent = "Creating order…";
      elements.action.disabled = true;
      break;
    case "refreshing":
      elements.dialogStatus.textContent = "Refreshing order…";
      elements.action.disabled = true;
      break;
    case "pending":
    case "accepted":
      elements.dialogStatus.textContent = "Order is being processed.";
      elements.action.textContent = "Refresh order";
      break;
    case "succeeded":
      elements.dialogStatus.textContent = "Purchase completed ✅";
      elements.action.textContent = "Request new quote";
      telegram?.HapticFeedback?.notificationOccurred("success");
      break;
    case "failed":
      elements.dialogStatus.textContent = state.error || "The operation failed.";
      elements.action.textContent = "Try again";
      telegram?.HapticFeedback?.notificationOccurred("error");
      break;
    default:
      elements.dialogStatus.textContent = "The current price will be validated before purchase.";
      elements.action.textContent = "Request quote";
  }
}

function syncViewport() {
  if (!store) return;
  store.setPageSize(viewportPageSize());
  renderCatalog();
}

async function start() {
  telegram?.ready();
  telegram?.setHeaderColor?.("secondary_bg_color");
  telegram?.setBackgroundColor?.("secondary_bg_color");

  const snapshot = await loadCatalogOnce();
  store = new CatalogStore(snapshot, { pageSize: viewportPageSize() });
  elements.snapshot.textContent = `${snapshot.id.slice(0, 8)} · ${snapshot.count}`;
  renderCategories(snapshot);
  renderCatalog();
}

elements.search.addEventListener("input", (event) => {
  store.setQuery(event.currentTarget.value);
  renderCatalog();
});
elements.category.addEventListener("change", (event) => {
  store.setCategory(event.currentTarget.value);
  renderCatalog();
});
elements.previous.addEventListener("click", () => {
  store.previous();
  renderCatalog();
  telegram?.HapticFeedback?.selectionChanged();
});
elements.home.addEventListener("click", () => {
  elements.category.value = "";
  store.setCategory(null);
  store.home();
  renderCatalog();
});
elements.next.addEventListener("click", () => {
  store.next();
  renderCatalog();
  telegram?.HapticFeedback?.selectionChanged();
});
elements.closeDialog.addEventListener("click", () => elements.dialog.close());
elements.action.addEventListener("click", () => performCheckoutAction().catch((error) => {
  elements.dialogStatus.textContent = error.message;
  elements.action.disabled = false;
}));
window.addEventListener("resize", syncViewport, { passive: true });
telegram?.onEvent?.("viewportChanged", syncViewport);

start().catch((error) => {
  elements.status.textContent = error.message;
  elements.status.dataset.error = "true";
});
