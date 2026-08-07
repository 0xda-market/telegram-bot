import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createTelegramTransport } from "../webapp/adapter/telegram-transport.js";

function response(document, { ok = true, status = 200 } = {}) {
  return { ok, status, async json() { return document; } };
}

test("preserves the complete bootstrap document and caches it", async () => {
  const calls = [];
  const document = { data: [{ id: "product-1" }], meta: { complete: true, session: { role: "broker" } } };
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, fetchImpl: async (url) => { calls.push(url); return response(document); } });
  assert.equal(await transport.bootstrap({ locale: "uk_UA" }), document);
  assert.equal(await transport.bootstrap({ locale: "uk_UA" }), document);
  assert.equal(calls.length, 1);
});

test("clears a timed-out bootstrap so startup retry issues a new request", async () => {
  let calls = 0;
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    requestTimeoutMs: 5,
    fetchImpl: async (_url, { signal }) => {
      calls += 1;
      return new Promise((_resolve, reject) => signal.addEventListener("abort", () => reject(signal.reason), { once: true }));
    }
  });

  await assert.rejects(() => transport.bootstrap({ locale: "uk_UA" }), /timed out after 5 ms/);
  await assert.rejects(() => transport.bootstrap({ locale: "uk_UA" }), /timed out after 5 ms/);
  assert.equal(calls, 2);
});

test("adapts quantity checkout and broker listing resources", async () => {
  const calls = [];
  const resource = { type: "quote", id: "quote-1", attributes: {} };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options) => { calls.push([url, options]); return response({ status: "ok", data: resource }); }
  });
  assert.equal(await transport.quote({ sku: "premium_3m", quantity: "2", locale: "uk_UA" }), resource);
  assert.deepEqual(JSON.parse(calls[0][1].body), { sku: "premium_3m", quantity: "2", locale: "uk_UA" });
  assert.equal(await transport.listBrokerListings(), resource);
  await transport.createBrokerListing({ sku: "btc", quantity: "0.25", priceAmount: "65000.12", currency: "USDT" });
  await transport.updateBrokerListing({ listingId: "listing-1", quantity: "0.5", priceAmount: "64000", currency: "USDT", version: 0 });
  await transport.withdrawBrokerListing({ listingId: "listing-1", version: 1 });
  assert.equal(calls[2][1].method, "POST");
  assert.equal(calls[3][1].method, "PATCH");
  assert.equal(calls[4][1].method, "DELETE");
});

test("adapts broker order decisions without exposing the actor UUID", async () => {
  const calls = [];
  const resource = { type: "broker_order", id: "order-1", attributes: { version: 0 } };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options = {}) => { calls.push([url, options]); return response({ status: "ok", data: url.endsWith("/orders") ? [resource] : resource }); }
  });
  assert.deepEqual(await transport.listBrokerOrders(), [resource]);
  await transport.acceptBrokerOrder({ orderId: "order-1", version: 0 });
  await transport.completeBrokerOrder({ orderId: "order-1", version: 1, data: { delivered: true } });
  assert.match(calls[0][0], /broker\/orders$/);
  assert.deepEqual(JSON.parse(calls[1][1].body), { version: 0 });
  assert.deepEqual(JSON.parse(calls[2][1].body), { version: 1, data: { delivered: true } });
  assert.equal(calls.some(([, options]) => String(options.body || "").includes("actor_user_id")), false);
});

test("adapts administrator creation and editing without exposing the actor UUID", async () => {
  const calls = [];
  const resource = { type: "product", id: "premium_3m", attributes: { version: 2 } };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options = {}) => { calls.push([url, options]); return response({ status: "ok", data: url.includes("?locale=") ? [resource] : resource }); }
  });
  assert.deepEqual(await transport.listAdminProducts({ locale: "uk_UA" }), [resource]);
  await transport.createAdminProduct({
    sku: "premium_12m",
    attributes: { short_name: "Premium · 12m", status: "inactive", position: 3, marketable: true, metadata: { family: "telegram_premium", duration_months: 12 } },
    localization: { locale: "uk_UA", fullName: "Telegram Premium на 12 місяців", buttonLabel: "Premium · 12 міс." }
  });
  await transport.updateAdminProduct({ sku: "premium_3m", version: 2, attributes: { short_name: "Premium · 3m" } });
  await transport.saveAdminProductLocalization({ sku: "premium_3m", locale: "uk_UA", fullName: "Telegram Premium на 3 місяці", buttonLabel: "Premium · 3 міс.", version: 1 });
  assert.equal(calls[1][1].method, "POST");
  assert.equal(calls[2][1].method, "PATCH");
  assert.equal(calls[3][1].method, "PUT");
  assert.equal(calls.some(([, options]) => String(options.body || "").includes("actor_user_id")), false);
});

test("preserves price proposal metadata and submits its exact revision", async () => {
  const calls = [];
  const proposal = { data: [{ id: "premium_3m" }], meta: { revision: 7 } };
  const history = { data: [{ id: "6" }], meta: { revision: 7 } };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      if (url.includes("/proposal")) return response(proposal);
      if (url.includes("/history")) return response(history);
      return response({ status: "ok", data: [], meta: { revision: 9 } }, { status: 201 });
    }
  });
  assert.equal(await transport.getAdminPriceProposal({ locale: "uk_UA" }), proposal);
  assert.equal(await transport.listAdminPriceHistory({ limit: 12 }), history);
  const applied = await transport.applyAdminPrices({ revision: 7, prices: [{ sku: "premium_3m", amount_usdt: "12.75" }] });
  assert.equal(applied.meta.revision, 9);
});

test("rejects a successful POST document without status ok", async () => {
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, fetchImpl: async () => response({ data: {} }, { status: 201 }) });
  await assert.rejects(() => transport.quote({ sku: "premium_3m", quantity: "1", locale: "uk_UA" }), /missing status: ok/);
});

test("rejects a nominal HTTP success carrying status error", async () => {
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, fetchImpl: async () => response({ status: "error", message: "write rejected", data: {} }, { status: 200 }) });
  await assert.rejects(() => transport.quote({ sku: "premium_3m", quantity: "1", locale: "uk_UA" }), /write rejected/);
});

test("pins and mounts the current webapp-core contracts", () => {
  const source = readFileSync(new URL("../webapp/app.js", import.meta.url), "utf8");
  assert.match(source, /aa678e3cb439bc6d242221668f2e7a16d31dbb88/);
  assert.match(source, /checkout-feedback-state\.js/);
  assert.match(source, /createCheckoutFeedbackState/);
  assert.match(source, /withCheckoutFeedback/);
  assert.match(source, /mountBrokerWorkspace/);
  assert.match(source, /mountBrokerOrders/);
  assert.match(source, /mountAdminWorkspace/);
  assert.match(source, /mountWorkspaceNavigation/);
  assert.doesNotMatch(source, /webapp-core@master/);
});
