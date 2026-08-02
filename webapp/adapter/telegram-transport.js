export function createTelegramTransport({
  telegram = globalThis.Telegram?.WebApp,
  apiBaseUrl = ".",
  fetchImpl = globalThis.fetch
} = {}) {
  let bootstrapPromise;

  async function requestDocument(path, options = {}) {
    const initData = telegram?.initData || "";
    if (!initData) throw new Error("Open this Web App inside Telegram.");
    if (typeof fetchImpl !== "function") throw new Error("Web App transport is unavailable.");

    const response = await fetchImpl(`${apiBaseUrl}${path}`, {
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

  async function requestResource(path, options = {}) {
    const document = await requestDocument(path, options);
    if (!("data" in document)) throw new Error("Web App resource response is missing data.");
    return document.data;
  }

  return {
    bootstrap({ locale }) {
      bootstrapPromise ||= requestDocument(`/bootstrap?${new URLSearchParams({ locale })}`);
      return bootstrapPromise;
    },
    quote({ sku, locale }) {
      return requestResource("/quotes", {
        method: "POST",
        body: JSON.stringify({ sku, locale })
      });
    },
    acceptQuote({ quoteId }) {
      return requestResource(`/quotes/${encodeURIComponent(quoteId)}/accept`, {
        method: "POST",
        body: "{}"
      });
    },
    refreshOrder({ orderId }) {
      return requestResource(`/orders/${encodeURIComponent(orderId)}`);
    },
    listBrokerListings() {
      return requestResource("/broker/listings");
    },
    createBrokerListing({ sku, quantity, priceAmount, currency }) {
      return requestResource("/broker/listings", {
        method: "POST",
        body: JSON.stringify({ sku, quantity, price_amount: priceAmount, currency })
      });
    },
    updateBrokerListing({ listingId, quantity, priceAmount, currency, version }) {
      return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, {
        method: "PATCH",
        body: JSON.stringify({ quantity, price_amount: priceAmount, currency, version })
      });
    },
    withdrawBrokerListing({ listingId, version }) {
      return requestResource(`/broker/listings/${encodeURIComponent(listingId)}`, {
        method: "DELETE",
        body: JSON.stringify({ version })
      });
    },
    listAdminProducts({ locale }) {
      return requestResource(`/admin/products?${new URLSearchParams({ locale })}`);
    },
    updateAdminProduct({ sku, version, attributes }) {
      return requestResource(`/admin/products/${encodeURIComponent(sku)}`, {
        method: "PATCH",
        body: JSON.stringify({ version, attributes })
      });
    },
    saveAdminProductLocalization({ sku, locale, fullName, buttonLabel, version }) {
      return requestResource(
        `/admin/products/${encodeURIComponent(sku)}/localizations/${encodeURIComponent(locale)}`,
        {
          method: "PUT",
          body: JSON.stringify({
            full_name: fullName,
            button_label: buttonLabel,
            ...(version === undefined ? {} : { version })
          })
        }
      );
    }
  };
}
