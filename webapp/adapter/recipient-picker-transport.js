function apiError(document, status) {
  const message = document?.message || document?.error || `HTTP ${status}`;
  return new Error(message);
}

export function createRecipientPickerTransport({
  telegram = globalThis.Telegram?.WebApp,
  apiBaseUrl = ".",
  fetchImpl = globalThis.fetch
} = {}) {
  async function request(path, options = {}) {
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
    if (!response.ok) throw apiError(document, response.status);
    if (String(options.method || "GET").toUpperCase() === "POST" && document.status !== "ok") {
      throw apiError(document, response.status);
    }
    if (!("data" in document)) throw new Error("Recipient picker response is missing data.");
    return document.data;
  }

  return {
    prepareRecipientPicker() {
      return request("/webapp/recipient-picker", { method: "POST", body: "{}" });
    },
    getRecipientPickerResult(token) {
      return request(`/webapp/recipient-picker/${encodeURIComponent(token)}`);
    }
  };
}
