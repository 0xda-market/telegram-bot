const DEFAULT_REQUEST_TIMEOUT_MS = 15_000;

const ERROR_MESSAGES = Object.freeze({
  en_US: Object.freeze({
    single_quantity_only: "This product can only be purchased one at a time.",
    recipient_username_required: "Enter the recipient's Telegram username.",
    recipient_mode_unsupported: "This recipient option is not supported for the product.",
    recipient_identity_unavailable: "Your Telegram username is required to buy this product for yourself.",
    recipient_ambiguous: "This username cannot be resolved safely.",
    premium_already_active: "Telegram Premium is already active for this recipient."
  }),
  uk_UA: Object.freeze({
    insufficient_liquidity: "Недостатньо доступної пропозиції брокерів для цього замовлення.",
    quote_reprice_required: "Умови пропозиції змінилися. Отримайте нову ціну.",
    concurrency_conflict: "Дані вже змінилися. Оновіть їх і спробуйте ще раз.",
    payment_required: "Потрібне підтвердження оплати.",
    broker_acceptance_required: "Спочатку потрібно погодити замовлення.",
    fulfillment_not_ready: "Замовлення ще не готове до виконання.",
    fulfillment_incomplete: "Не вдалося завершити виконання замовлення.",
    duplicate_active_listing: "Для цього активу й валюти вже є активне оголошення.",
    single_quantity_only: "Цей продукт можна купити лише по одному.",
    recipient_username_required: "Вкажіть Telegram username одержувача.",
    recipient_mode_unsupported: "Цей варіант одержувача недоступний для продукту.",
    recipient_identity_unavailable: "Для купівлі собі потрібен ваш Telegram username.",
    recipient_ambiguous: "Не вдалося однозначно визначити цей username.",
    premium_already_active: "У цього одержувача Telegram Premium уже активний.",
    missing_field: "У запиті бракує обов’язкових даних.",
    validation_error: "Перевірте введені дані й спробуйте ще раз.",
    unauthorized: "Потрібна авторизація.",
    forbidden: "Недостатньо прав для цієї дії.",
    not_found: "Запитаний ресурс не знайдено."
  }),
  ru_RU: Object.freeze({
    single_quantity_only: "Этот продукт можно купить только по одному.",
    recipient_username_required: "Укажите Telegram username получателя.",
    recipient_mode_unsupported: "Этот вариант получателя недоступен для продукта.",
    recipient_identity_unavailable: "Для покупки себе требуется ваш Telegram username.",
    recipient_ambiguous: "Не удалось однозначно определить этот username.",
    premium_already_active: "У этого получателя Telegram Premium уже активен."
  })
});

function normalizeLocale(locale) {
  const language = String(locale || "en_US").toLowerCase().split(/[-_]/, 1)[0];
  return ({ uk: "uk_UA", ru: "ru_RU", en: "en_US" })[language] || "en_US";
}

function apiError(document, status, locale) {
  const first = Array.isArray(document?.errors) ? document.errors[0] : null;
  const code = String(first?.code || document?.code || "");
  const localized = ERROR_MESSAGES[normalizeLocale(locale)]?.[code] || ERROR_MESSAGES.en_US[code];
  const fallback = first?.message || document?.message || document?.error || `HTTP ${status}`;
  const error = new Error(localized || fallback);
  if (code) error.code = code;
  if (first?.details || document?.details) error.details = first?.details || document?.details;
  return error;
}

function timeoutError(milliseconds, locale) {
  const messages = {
    uk_UA: `Час очікування відповіді минув (${milliseconds} мс).`,
    ru_RU: `Время ожидания ответа истекло (${milliseconds} мс).`,
    en_US: `Web App request timed out after ${milliseconds} ms.`
  };
  const error = new Error(messages[normalizeLocale(locale)]);
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
      const messages = { uk_UA: "Відкрийте застосунок у Telegram.", ru_RU: "Откройте приложение в Telegram.", en_US: "Open this Web App inside Telegram." };
      throw new Error(messages[normalizeLocale(locale)]);
    }
    if (typeof fetchImpl !== "function") {
      const messages = { uk_UA: "З’єднання із застосунком недоступне.", ru_RU: "Соединение с приложением недоступно.", en_US: "Web App transport is unavailable." };
      throw new Error(messages[normalizeLocale(locale)]);
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
    quote({ sku, quantity, recipient, locale }) { return requestResource("/quotes", { method: "POST", body: JSON.stringify({ sku, quantity, recipient, locale }), locale }); },
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
