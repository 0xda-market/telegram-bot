const DEFAULT_REQUEST_TIMEOUT_MS = 15_000;

const ERROR_MESSAGES = Object.freeze({
  uk_UA: Object.freeze({
    insufficient_liquidity: "Недостатньо доступної пропозиції брокерів для цього замовлення.",
    quote_reprice_required: "Умови пропозиції змінилися. Отримайте нову ціну.",
    concurrency_conflict: "Дані вже змінилися. Оновіть їх і спробуйте ще раз.",
    payment_required: "Потрібне підтвердження оплати.",
    broker_acceptance_required: "Спочатку потрібно погодити замовлення.",
    fulfillment_not_ready: "Замовлення ще не готове до виконання.",
    fulfillment_incomplete: "Не вдалося завершити виконання замовлення.",
    duplicate_active_listing: "Для цього активу й валюти вже є активне оголошення.",
    missing_field: "У запиті бракує обов’язкових даних.",
    validation_error: "Перевірте введені дані й спробуйте ще раз.",
    unauthorized: "Потрібна авторизація.",
    forbidden: "Недостатньо прав для цієї дії.",
    not_found: "Запитаний ресурс не знайдено."
  })
});

function normalizeLocale(locale) {
  return String(locale || "en_US").toLowerCase().startsWith("uk") ? "uk_UA" : "en_US";
}

function apiError(document, status, locale) {
  const first = Array.isArray(document?.errors) ? document.errors[0] : null;
  const code = String(first?.code || document?.code || "");
  const localized = ERROR_MESSAGES[normalizeLocale(locale)]?.[code];
  const fallback = first?.message || document?.message || document?.error || `HTTP ${status}`;
  const error = new Error(localized || fallback);
  if (code) error.code = code;
  if (first?.details || document?.details) error.details = first?.details || document?.details;
  return error;
}

function timeoutError(milliseconds, locale) {
  const error = new Error(
    normalizeLocale(locale) === "uk_UA"
      ? `Час очікування відповіді минув (${milliseconds} мс).`
      : `Web App request timed out after ${milliseconds} ms.`
  );
  error.code = "request_timeout";
  return error;
}

export function createTelegramTransport({
  telegram = globalThis.Telegram?.WebApp,
  apiBaseUrl = ".",
  fetchImpl = globalThis.fetch,
  requestTimeoutMs = DEFAULT_REQUEST_TIMEOUT_MS,
  locale: defaultLocale = "en_US"
} = {}) {
  let bootstrapPromise;

  async function requestDocument(path, options = {}) {
    const initData = telegram?.initData || "";
    const locale = options.locale || defaultLocale;
    if (!initData) {
      throw new Error(normalizeLocale(locale) === "uk_UA" ? "Відкрийте застосунок у Telegram." : "Open this Web App inside Telegram.");
    }
    if (typeof fetchImpl !== "function") {
      throw new Error(normalizeLocale(locale) === "uk_UA" ? "З’єднання із застосунком недоступне." : "Web App transport is unavailable.");
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(timeoutError(requestTimeoutMs, locale)), requestTimeoutMs);

    try {
      const { locale: _locale, ...fetchOptions } = options;
      const response = await fetchImpl(`${apiBaseUrl}${path}`, {
        ...fetchOptions,
        signal: controller.signal,
        headers: { accept: "application/json", "content-type": "application/json", "x-telegram-init-data": initData, ...(fetchOptions.headers || {}) }
      });
      const document = await response.json().catch(() => ({}));
      if (!response.ok) throw apiError(document, response.status, locale);
      if (String(fetchOptions.method || "GET").toUpperCase() === "POST" && document.status !== "ok") {
        throw apiError(document, response.status, locale);
      }
      return document;
    } catch (error) {
      if (controller.signal.aborted) throw controller.signal.reason || timeoutError(requestTimeoutMs, locale);
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
      bootstrapPromise ||= requestDocument(`/bootstrap?${new URLSearchParams({ locale })}`, { locale })
        .catch((error) => {
          bootstrapPromise = undefined;
          throw error;
        });
      return bootstrapPromise;
    },
    reportRuntimeEvent(event) {
      return requestDocument("/runtime-events", { method: "POST", body: JSON.stringify(event) });
    },
    quote({ sku, quantity, locale }) { return requestResource("/quotes", { method: "POST", body: JSON.stringify({ sku, quantity, locale }), locale }); },
    acceptQuote({ quoteId }) { return requestResource(`/quotes/${encodeURIComponent(quoteId)}/accept`, { method: "POST", body: "{}" }); },
    refreshOrder({ orderId }) { return requestResource(`/orders/${encodeURIComponent(orderId)}`); },
    listBrokerListings() { return requestResource("/broker/listings"); },
    createBrokerListing({ sku, quantity, priceAmount, currency }) { return requestResource("/broker/listings", { method: "POST", body: JSON.stringify({ sku, quantity, price_amount: priceAmount, currency }) }); },
    updateBrokerListing({ listingId, quantity, priceAmount, currency, version }) { return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, { method: "PATCH", body: JSON.stringify({ quantity, price_amount: priceAmount, currency, version }) }); },
    withdrawBrokerListing({ listingId, version }) { return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, { method: "DELETE", body: JSON.stringify({ version }) }); },
    listBrokerOrders() { return requestResource("/broker/orders"); },
    acceptBrokerOrder({ orderId, version }) { return requestResource(`/broker/orders/${encodeURIComponent(orderId)}/accept`, { method: "POST", body: JSON.stringify({ version }) }); },
    completeBrokerOrder({ orderId, version, reference, data = {} }) { return requestResource(`/broker/orders/${encodeURIComponent(orderId)}/complete`, { method: "POST", body: JSON.stringify({ version, reference, data }) }); },
    listAdminProducts({ locale }) { return requestResource(`/admin/products?${new URLSearchParams({ locale })}`, { locale }); },
    createAdminProduct({ sku, attributes, localization }) { return requestResource("/admin/products", { method: "POST", body: JSON.stringify({ sku, attributes, localization: { locale: localization.locale, full_name: localization.fullName, button_label: localization.buttonLabel } }), locale: localization.locale }); },
    updateAdminProduct({ sku, version, attributes }) { return requestResource(`/admin/products/${encodeURIComponent(sku)}`, { method: "PATCH", body: JSON.stringify({ version, attributes }) }); },
    saveAdminProductLocalization({ sku, locale, fullName, buttonLabel, version }) { return requestResource(`/admin/products/${encodeURIComponent(sku)}/localizations/${encodeURIComponent(locale)}`, { method: "PUT", body: JSON.stringify({ full_name: fullName, button_label: buttonLabel, ...(version === undefined ? {} : { version }) }), locale }); },
    getAdminPriceProposal({ locale }) { return requestDocument(`/admin/prices/proposal?${new URLSearchParams({ locale })}`, { locale }); },
    listAdminPriceHistory({ limit = 20 } = {}) { return requestDocument(`/admin/prices/history?${new URLSearchParams({ limit: String(limit) })}`); },
    applyAdminPrices({ revision, prices }) { return requestDocument("/admin/prices", { method: "POST", body: JSON.stringify({ revision, prices }) }); }
  };
}
