export function createTelegramTransport({
  telegram = globalThis.Telegram?.WebApp,
  apiBaseUrl = "."
} = {}) {
  async function request(path, options = {}) {
    const initData = telegram?.initData || "";
    if (!initData) throw new Error("Open this Web App inside Telegram.");

    const response = await fetch(`${apiBaseUrl}${path}`, {
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
    return document.data ?? document;
  }

  return {
    bootstrap({ locale }) {
      return request(`/bootstrap?${new URLSearchParams({ locale })}`);
    },
    quote({ sku, locale }) {
      return request("/quotes", {
        method: "POST",
        body: JSON.stringify({ sku, locale })
      });
    },
    acceptQuote({ quoteId }) {
      return request(`/quotes/${encodeURIComponent(quoteId)}/accept`, {
        method: "POST",
        body: "{}"
      });
    },
    refreshOrder({ orderId }) {
      return request(`/orders/${encodeURIComponent(orderId)}`);
    }
  };
}
