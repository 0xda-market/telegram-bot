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

  await assert.rejects(() => transport.bootstrap({ locale: "uk_UA" }), /Час очікування відповіді минув \(5 мс\)/);
  await assert.rejects(() => transport.bootstrap({ locale: "uk_UA" }), /Час очікування відповіді минув \(5 мс\)/);
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

test("localizes structured API errors for Ukrainian without exposing backend copy", async () => {
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    locale: "uk_UA",
    fetchImpl: async () => response({
      status: "error",
      errors: [{ code: "insufficient_liquidity", message: "insufficient broker liquidity", details: { sku: "premium_3m" } }]
    }, { ok: false, status: 409 })
  });

  await assert.rejects(
    () => transport.quote({ sku: "premium_3m", quantity: "1", locale: "uk_UA" }),
    /Недостатньо доступної пропозиції брокерів для цього замовлення/
  );
});

test("keeps unknown backend errors as a fallback", async () => {
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    locale: "uk_UA",
    fetchImpl: async () => response({ errors: [{ code: "future_error", message: "future backend message" }] }, { ok: false, status: 409 })
  });
  await assert.rejects(() => transport.listBrokerListings(), /future backend message/);
});

test("rejects a successful POST document without status ok", async () => {
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, fetchImpl: async () => response({ data: {} }, { status: 201 }) });
  await assert.rejects(() => transport.quote({ sku: "premium_3m", quantity: "1", locale: "en_US" }), /HTTP 201/);
});

test("rejects a nominal HTTP success carrying status error", async () => {
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, fetchImpl: async () => response({ status: "error", message: "write rejected", data: {} }, { status: 200 }) });
  await assert.rejects(() => transport.quote({ sku: "premium_3m", quantity: "1", locale: "en_US" }), /write rejected/);
});

test("pins and mounts the current webapp-core contracts", () => {
  const source = readFileSync(new URL("../webapp/app.js", import.meta.url), "utf8");
  assert.match(source, /a062196e06364a98a6ec405c402131c2e0fc46f5/);
  assert.match(source, /checkout-feedback-state\.js/);
  assert.match(source, /createCheckoutFeedbackState/);
  assert.match(source, /withCheckoutFeedback/);
  assert.match(source, /pickTelegramRecipient/);
  assert.match(source, /mountBrokerWorkspace/);
  assert.match(source, /mountBrokerOrders/);
  assert.match(source, /mountAdminWorkspace/);
  assert.match(source, /mountWorkspaceNavigation/);
  assert.doesNotMatch(source, /webapp-core@master/);
});


test("paper replay uses the verified Telegram transport without exposing a service token", async () => {
  const calls = [];
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options) => { calls.push([url, options]); return response({ status: "ok", data: { equity: "1000.0" } }); }
  });
  assert.deepEqual(await transport.replayTrading({ events: [], options: { starting_cash: "1000" } }), { equity: "1000.0" });
  assert.match(calls[0][0], /trading\/replays$/);
  assert.equal(calls[0][1].headers["x-telegram-init-data"], "signed");
  assert.deepEqual(JSON.parse(calls[0][1].body), { events: [], options: { starting_cash: "1000" } });
  assert.equal(JSON.stringify(calls).includes("TRADING_LAB_TOKEN"), false);
});

test("leaderboard is a signed GET with encoded read-only filters", async () => {
  const calls = [];
  const transport = createTelegramTransport({
    telegram: { initData: "signed" },
    fetchImpl: async (url, options) => { calls.push([url, options]); return response({ status: "ok", data: { data_version: "20261105150001", traders: [] } }); }
  });
  assert.deepEqual(await transport.tradingLeaders({ sort: "pnl_ratio", limit: "20", min_lead_days: "90" }), { data_version: "20261105150001", traders: [] });
  assert.match(calls[0][0], /\/trading\/leaders\?sort=pnl_ratio&limit=20&min_lead_days=90$/);
  assert.equal(calls[0][1].method ?? "GET", "GET");
  assert.equal(calls[0][1].body, undefined);
  assert.equal(calls[0][1].headers["x-telegram-init-data"], "signed");
  await transport.tradingLeaders();
  assert.match(calls[1][0], /\/trading\/leaders$/);
  assert.equal(JSON.stringify(calls).includes("TRADING_LAB_TOKEN"), false);
});

test("Trading Lab outages are shown in the person's language, never as English or Ruby internals", async () => {
  const expected = {
    uk_UA: { trading_lab_unavailable: "Trading Lab тимчасово недоступний. Спробуйте ще раз за хвилину.", trading_lab_timeout: "Trading Lab не відповів вчасно. Спробуйте ще раз за хвилину." },
    ru_RU: { trading_lab_unavailable: "Trading Lab временно недоступен. Попробуйте ещё раз через минуту.", trading_lab_timeout: "Trading Lab не ответил вовремя. Попробуйте ещё раз через минуту." },
    en_US: { trading_lab_unavailable: "Trading Lab is temporarily unavailable. Try again in a minute.", trading_lab_timeout: "Trading Lab did not respond in time. Try again in a minute." }
  };
  for (const [locale, codes] of Object.entries(expected)) {
    for (const [code, text] of Object.entries(codes)) {
      const transport = createTelegramTransport({
        telegram: { initData: "signed" },
        locale,
        fetchImpl: async () => response(
          { status: "error", error: "trading_lab_unavailable", code, message: "Trading Lab copy replay is unavailable (Net::ReadTimeout)" },
          { ok: false, status: 502 }
        )
      });
      await assert.rejects(() => transport.copyTrading({ uniqueCode: "9A8534AB09862774" }),
        (error) => error.message === text && error.code === code, `${locale} ${code} copy`);
      await assert.rejects(() => transport.tradingLeaders(), (error) => error.message === text, `${locale} ${code} leaderboard`);
    }
  }
});

test("a failed copy job submit or poll is shown in the person's language, never as HTTP or Ruby internals", async () => {
  const id = "a".repeat(32);
  const outage = (message, code = "trading_lab_unavailable") =>
    response({ status: "error", error: "trading_lab_unavailable", code, message }, { ok: false, status: 502 });
  const queued = () => response({ status: "ok", data: { job_id: id, state: "queued" } }, { status: 202 });
  const attempt = (replies, locale = "uk_UA") => createTelegramTransport({
    telegram: { initData: "signed" }, locale, copyPollDelayMs: 0, fetchImpl: async () => replies.shift()
  }).copyTrading({ uniqueCode: "9A8534AB09862774" });

  await assert.rejects(() => attempt([outage("Trading Lab copy job submit is unavailable")]),
    (error) => error.message === "Trading Lab тимчасово недоступний. Спробуйте ще раз за хвилину." && error.code === "trading_lab_unavailable");
  await assert.rejects(() => attempt([queued(), outage("x", "trading_lab_timeout"), outage("x", "trading_lab_timeout"), outage("x", "trading_lab_timeout")]),
    (error) => error.message === "Trading Lab не відповів вчасно. Спробуйте ще раз за хвилину." && error.code === "trading_lab_timeout");
  await assert.rejects(() => attempt([outage("Trading Lab copy job submit is unavailable")], "en_US"),
    (error) => error.message === "Trading Lab is temporarily unavailable. Try again in a minute.");
  await assert.rejects(() => attempt([response({ status: "ok", data: { job_id: id, state: "failed", error: "something_new" } }, { status: 202 })]),
    (error) => error.message === "Симуляція завершилася помилкою. Результат не розраховано." && error.code === "replay_internal_error");
});

test("copy trading submits then polls through the signed transport", async () => {
  const calls = [];
  const jobId = "a".repeat(32);
  const replies = [
    response({ status: "ok", data: { job_id: jobId, state: "queued" } }, { status: 202 }),
    response({ status: "ok", data: { job_id: jobId, state: "running" } }),
    response({ status: "ok", data: { job_id: jobId, state: "succeeded", data: { copied: 3 } } })
  ];
  const transport = createTelegramTransport({
    telegram: { initData: "signed" }, copyPollDelayMs: 0,
    fetchImpl: async (url, options) => { calls.push([url, options]); return replies.shift(); }
  });
  assert.deepEqual(await transport.copyTrading({ uniqueCode: "9A8534AB09862774", options: { trade_notional: "50" } }), { copied: 3 });
  assert.match(calls[0][0], /\/trading\/copy-replay-jobs$/);
  assert.equal(calls[0][1].method, "POST");
  assert.deepEqual(JSON.parse(calls[0][1].body), { unique_code: "9A8534AB09862774", options: { trade_notional: "50" } });
  assert.equal(calls.length, 3);
  for (const [, options] of calls) assert.equal(options.headers["x-telegram-init-data"], "signed");
  assert.ok(calls.slice(1).every(([url]) => url.endsWith("/" + jobId)));
});

test("copy job retries a transient status error but never fabricates a result", async () => {
  const id = "a".repeat(32);
  const replies = [
    response({ status: "ok", data: { job_id: id, state: "queued" } }, { status: 202 }),
    response({}, { ok: false, status: 502 }),
    response({ status: "ok", data: { job_id: id, state: "failed", error: "upstream_data_error" } })
  ];
  const transport = createTelegramTransport({ telegram: { initData: "signed" }, locale: "uk_UA", copyPollDelayMs: 0,
    fetchImpl: async () => replies.shift() });
  await assert.rejects(() => transport.copyTrading({ uniqueCode: "9A8534AB09862774" }), /Не вдалося перевірити дані OKX/);
  assert.equal(replies.length, 0);
});
