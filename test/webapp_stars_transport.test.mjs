import test from "node:test";
import assert from "node:assert/strict";
import { createTelegramTransport } from "../webapp/adapter/telegram-transport.js";

function response(document, { ok = true, status = 200 } = {}) {
  return { ok, status, async json() { return document; } };
}

function pendingOrder() {
  return {
    type: "order",
    id: "order:quote-1",
    attributes: {
      status: "payment_pending",
      payment_status: "pending",
      payment: {
        status: "pending",
        invoice_link: "https://t.me/$invoice-1",
        provider: { provider: "telegram_stars", currency: "XTR", amount: "962" }
      }
    }
  };
}

test("paid Mini App callback only refreshes authoritative order state", async () => {
  const calls = [];
  let refreshes = 0;
  const telegram = {
    initData: "signed",
    openInvoice(url, callback) {
      assert.equal(url, "https://t.me/$invoice-1");
      callback("paid");
    }
  };
  const transport = createTelegramTransport({
    telegram,
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      if (url.includes("/quotes/") && url.endsWith("/accept")) {
        return response({ status: "ok", data: pendingOrder() }, { status: 201 });
      }
      refreshes += 1;
      const order = pendingOrder();
      if (refreshes >= 2) {
        order.attributes.status = "pending";
        order.attributes.payment_status = "confirmed";
        order.attributes.payment.status = "confirmed";
      }
      return response({ data: order });
    }
  });

  const result = await transport.acceptQuote({ quoteId: "quote-1" });

  assert.equal(result.attributes.payment_status, "confirmed");
  assert.equal(calls[0][1].method, "POST");
  assert.equal(calls.slice(1).every(([, options]) => !options.method || options.method === "GET"), true);
  assert.equal(calls.some(([url]) => url.includes("payment/confirm")), false);
});

test("cancelled Mini App callback leaves the core order payment pending", async () => {
  const calls = [];
  const transport = createTelegramTransport({
    telegram: {
      initData: "signed",
      openInvoice(_url, callback) { callback("cancelled"); }
    },
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      return response({ status: "ok", data: pendingOrder() }, { status: 201 });
    }
  });

  const result = await transport.acceptQuote({ quoteId: "quote-1" });
  assert.equal(result.attributes.payment_status, "pending");
  assert.equal(calls.length, 1);
});
