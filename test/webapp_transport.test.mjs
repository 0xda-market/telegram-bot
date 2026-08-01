import test from "node:test";
import assert from "node:assert/strict";
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

test("unwraps resource responses only for quote and order operations", async () => {
  const resource = { type: "quote", id: "quote-1", attributes: {} };
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async () => response({ data: resource, meta: { snapshot_id: "snapshot-1" } })
  });

  assert.equal(await transport.quote({ sku: "premium_3m", locale: "uk_UA" }), resource);
});
