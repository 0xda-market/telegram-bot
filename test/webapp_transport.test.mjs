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
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url) => { calls.push(url); return response(document); }
  });

  assert.equal(await transport.bootstrap({ locale: "uk_UA" }), document);
  assert.equal(await transport.bootstrap({ locale: "uk_UA" }), document);
  assert.equal(calls.length, 1);
  assert.match(calls[0], /bootstrap/);
});

test("unwraps quote, order and broker listing resources", async () => {
  const calls = [];
  const resource = { type: "quote", id: "quote-1", attributes: {} };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options) => {
      calls.push([url, options]);
      return response({ data: resource, meta: { snapshot_id: "snapshot-1" } });
    }
  });

  assert.equal(await transport.quote({ sku: "premium_3m", locale: "uk_UA" }), resource);
  assert.equal(await transport.listBrokerListings(), resource);
  await transport.createBrokerListing({ sku: "btc", quantity: "0.25", priceAmount: "65000.12", currency: "USDT" });
  await transport.updateBrokerListing({ listingId: "listing-1", quantity: "0.5", priceAmount: "64000", currency: "USDT", version: 0 });
  await transport.withdrawBrokerListing({ listingId: "listing-1", version: 1 });

  assert.match(calls[1][0], /broker\/listings$/);
  assert.equal(calls[2][1].method, "POST");
  assert.deepEqual(JSON.parse(calls[2][1].body), {
    sku: "btc", quantity: "0.25", price_amount: "65000.12", currency: "USDT"
  });
  assert.equal(calls[3][1].method, "PATCH");
  assert.equal(calls[4][1].method, "DELETE");
});

test("adapts administrator catalog operations without exposing the actor UUID", async () => {
  const calls = [];
  const resource = { type: "product", id: "premium_3m", attributes: { version: 2 } };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      return response({ data: url.includes("?locale=") ? [resource] : resource });
    }
  });

  assert.deepEqual(await transport.listAdminProducts({ locale: "uk_UA" }), [resource]);
  await transport.updateAdminProduct({
    sku: "premium_3m",
    version: 2,
    attributes: { short_name: "Premium · 3m" }
  });
  await transport.saveAdminProductLocalization({
    sku: "premium_3m",
    locale: "uk_UA",
    fullName: "Telegram Premium на 3 місяці",
    buttonLabel: "Premium · 3 міс.",
    version: 1
  });

  assert.match(calls[0][0], /admin\/products\?locale=uk_UA$/);
  assert.equal(calls[1][1].method, "PATCH");
  assert.deepEqual(JSON.parse(calls[1][1].body), {
    version: 2,
    attributes: { short_name: "Premium · 3m" }
  });
  assert.equal(calls[2][1].method, "PUT");
  assert.deepEqual(JSON.parse(calls[2][1].body), {
    full_name: "Telegram Premium на 3 місяці",
    button_label: "Premium · 3 міс.",
    version: 1
  });
  assert.equal(calls.some(([, options]) => String(options.body || "").includes("actor_user_id")), false);
});

test("pins and mounts the administrator catalog package contract", () => {
  const source = readFileSync(new URL("../webapp/app.js", import.meta.url), "utf8");
  assert.match(source, /daa8fa85fd1af05e988cc0154966df0da7aa1a4d/);
  assert.match(source, /mountBrokerWorkspace/);
  assert.match(source, /mountAdminWorkspace/);
  assert.match(source, /mountWorkspaceNavigation/);
  assert.match(source, /await admin\?\.ready/);
  assert.doesNotMatch(source, /webapp-core@master/);
});
