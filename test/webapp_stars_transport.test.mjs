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

function bootstrapDocument() {
  return {
    data: [],
    meta: {
      payment_terms: {
        version: "20260811v1",
        locale: "en_US",
        title: "0xda-market Purchase Terms",
        prompt: "Read the Purchase Terms before paying.",
        view_label: "View Terms",
        agree_label: "I read & agree",
        url: "https://market.example/webapp/terms?locale=en_US"
      }
    }
  };
}

test("paid Mini App callback only refreshes authoritative order state after explicit Terms consent", async () => {
  const calls = [];
  let refreshes = 0;
  const telegram = {
    initData: "signed",
    showPopup(_params, callback) { callback("agree"); },
    openLink() { throw new Error("terms link should not open when user agrees directly"); },
    openInvoice(url, callback) {
      assert.equal(url, "https://t.me/$invoice-1");
      callback("paid");
    }
  };
  const transport = createTelegramTransport({
    telegram,
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      if (url.includes("/bootstrap")) return response(bootstrapDocument());
      if (url.includes("/quotes/") && url.endsWith("/accept")) {
        const body = JSON.parse(options.body);
        assert.deepEqual(body, {
          consent: { accepted: true, version: "20260811v1", locale: "en_US" }
        });
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

  await transport.bootstrap({ locale: "en_US" });
  const result = await transport.acceptQuote({ quoteId: "quote-1" });

  assert.equal(result.attributes.payment_status, "confirmed");
  const acceptCall = calls.find(([url]) => url.includes("/quotes/") && url.endsWith("/accept"));
  assert.equal(acceptCall[1].method, "POST");
  assert.equal(calls.filter(([url]) => url.includes("/payment/confirm")).length, 0);
});

test("view Terms opens the public Terms page before consent and then allows checkout", async () => {
  const opened = [];
  const popupChoices = ["view", "agree"];
  let acceptedBody;
  const transport = createTelegramTransport({
    telegram: {
      initData: "signed",
      showPopup(_params, callback) { callback(popupChoices.shift()); },
      openLink(url) { opened.push(url); },
      openInvoice(_url, callback) { callback("cancelled"); }
    },
    fetchImpl: async (url, options = {}) => {
      if (url.includes("/bootstrap")) return response(bootstrapDocument());
      acceptedBody = JSON.parse(options.body);
      return response({ status: "ok", data: pendingOrder() }, { status: 201 });
    }
  });

  await transport.bootstrap({ locale: "en_US" });
  await transport.acceptQuote({ quoteId: "quote-1" });

  assert.deepEqual(opened, ["https://market.example/webapp/terms?locale=en_US"]);
  assert.equal(acceptedBody.consent.accepted, true);
  assert.equal(acceptedBody.consent.version, "20260811v1");
});

test("declining Terms creates no order and opens no invoice", async () => {
  const calls = [];
  let invoiceOpened = false;
  const transport = createTelegramTransport({
    telegram: {
      initData: "signed",
      showPopup(_params, callback) { callback("cancel"); },
      openLink() {},
      openInvoice() { invoiceOpened = true; }
    },
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      if (url.includes("/bootstrap")) return response(bootstrapDocument());
      throw new Error("accept request must not be sent after Terms decline");
    }
  });

  await transport.bootstrap({ locale: "en_US" });
  await assert.rejects(
    transport.acceptQuote({ quoteId: "quote-1" }),
    (error) => error.code === "payment_terms_not_accepted"
  );

  assert.equal(calls.filter(([url]) => url.includes("/accept")).length, 0);
  assert.equal(invoiceOpened, false);
});

test("cancelled Mini App invoice leaves the core order payment pending after consent", async () => {
  const calls = [];
  const transport = createTelegramTransport({
    telegram: {
      initData: "signed",
      showPopup(_params, callback) { callback("agree"); },
      openLink() {},
      openInvoice(_url, callback) { callback("cancelled"); }
    },
    fetchImpl: async (url, options = {}) => {
      calls.push([url, options]);
      if (url.includes("/bootstrap")) return response(bootstrapDocument());
      return response({ status: "ok", data: pendingOrder() }, { status: 201 });
    }
  });

  await transport.bootstrap({ locale: "en_US" });
  const result = await transport.acceptQuote({ quoteId: "quote-1" });
  assert.equal(result.attributes.payment_status, "pending");
  assert.equal(calls.filter(([url]) => url.includes("/accept")).length, 1);
});
