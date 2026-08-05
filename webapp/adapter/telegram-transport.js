const DEFAULT_REQUEST_TIMEOUT_MS = 15_000;

function timeoutError(milliseconds) {
  const error = new Error(`Web App request timed out after ${milliseconds} ms.`);
  error.code = "request_timeout";
  return error;
}

export function createTelegramTransport({
  telegram = globalThis.Telegram?.WebApp,
  apiBaseUrl = ".",
  fetchImpl = globalThis.fetch,
  requestTimeoutMs = DEFAULT_REQUEST_TIMEOUT_MS
} = {}) {
  let bootstrapPromise;

  async function requestDocument(path, options = {}) {
    const initData = telegram?.initData || "";
    if (!initData) throw new Error("Open this Web App inside Telegram.");
    if (typeof fetchImpl !== "function") throw new Error("Web App transport is unavailable.");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(timeoutError(requestTimeoutMs)), requestTimeoutMs);

    try {
      const response = await fetchImpl(`${apiBaseUrl}${path}`, {
        ...options,
        signal: controller.signal,
        headers: { accept: "application/json", "content-type": "application/json", "x-telegram-init-data": initData, ...(options.headers || {}) }
      });
      const document = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(document.message || document.error || `HTTP ${response.status}`);
      if (String(options.method || "GET").toUpperCase() === "POST" && document.status !== "ok") {
        throw new Error(document.message || document.error || "Web App POST response is missing status: ok.");
      }
      return document;
    } catch (error) {
      if (controller.signal.aborted) throw controller.signal.reason || timeoutError(requestTimeoutMs);
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function requestResource(path, options = {}) {
    const document = await requestDocument(path, options);
    if (!("data" in document)) throw new Error("Web App resource response is missing data.");
    return document.data;
  }

  return {
    bootstrap({ locale }) {
      bootstrapPromise ||= requestDocument(`/bootstrap?${new URLSearchParams({ locale })}`)
        .catch((error) => {
          bootstrapPromise = undefined;
          throw error;
        });
      return bootstrapPromise;
    },
    reportRuntimeEvent(event) {
      return requestDocument("/runtime-events", { method: "POST", body: JSON.stringify(event) });
    },
    quote({ sku, quantity, locale }) { return requestResource("/quotes", { method: "POST", body: JSON.stringify({ sku, quantity, locale }) }); },
    acceptQuote({ quoteId }) { return requestResource(`/quotes/${encodeURIComponent(quoteId)}/accept`, { method: "POST", body: "{}" }); },
    refreshOrder({ orderId }) { return requestResource(`/orders/${encodeURIComponent(orderId)}`); },
    listBrokerListings() { return requestResource("/broker/listings"); },
    createBrokerListing({ sku, quantity, priceAmount, currency }) { return requestResource("/broker/listings", { method: "POST", body: JSON.stringify({ sku, quantity, price_amount: priceAmount, currency }) }); },
    updateBrokerListing({ listingId, quantity, priceAmount, currency, version }) { return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, { method: "PATCH", body: JSON.stringify({ quantity, price_amount: priceAmount, currency, version }) }); },
    withdrawBrokerListing({ listingId, version }) { return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, { method: "DELETE", body: JSON.stringify({ version }) }); },
    listBrokerOrders() { return requestResource("/broker/orders"); },
    acceptBrokerOrder({ orderId, version }) { return requestResource(`/broker/orders/${encodeURIComponent(orderId)}/accept`, { method: "POST", body: JSON.stringify({ version }) }); },
    completeBrokerOrder({ orderId, version, reference, data = {} }) { return requestResource(`/broker/orders/${encodeURIComponent(orderId)}/complete`, { method: "POST", body: JSON.stringify({ version, reference, data }) }); },
    listAdminProducts({ locale }) { return requestResource(`/admin/products?${new URLSearchParams({ locale })}`); },
    createAdminProduct({ sku, attributes, localization }) { return requestResource("/admin/products", { method: "POST", body: JSON.stringify({ sku, attributes, localization: { locale: localization.locale, full_name: localization.fullName, button_label: localization.buttonLabel } }) }); },
    updateAdminProduct({ sku, version, attributes }) { return requestResource(`/admin/products/${encodeURIComponent(sku)}`, { method: "PATCH", body: JSON.stringify({ version, attributes }) }); },
    saveAdminProductLocalization({ sku, locale, fullName, buttonLabel, version }) { return requestResource(`/admin/products/${encodeURIComponent(sku)}/localizations/${encodeURIComponent(locale)}`, { method: "PUT", body: JSON.stringify({ full_name: fullName, button_label: buttonLabel, ...(version === undefined ? {} : { version }) }) }); },
    getAdminPriceProposal({ locale }) { return requestDocument(`/admin/prices/proposal?${new URLSearchParams({ locale })}`); },
    listAdminPriceHistory({ limit = 20 } = {}) { return requestDocument(`/admin/prices/history?${new URLSearchParams({ limit: String(limit) })}`); },
    applyAdminPrices({ revision, prices }) { return requestDocument("/admin/prices", { method: "POST", body: JSON.stringify({ revision, prices }) }); }
  };
}
