import assert from "node:assert/strict";
import test from "node:test";

import { applyDaypart, observeDaypart, resolveDaypart } from "../webapp/adapter/daypart.js";

const at = (hour, minute = 0) => new Date(2026, 0, 15, hour, minute);

function fakeDocument(visibilityState = "visible") {
  return {
    documentElement: { dataset: {} },
    visibilityState,
    listeners: new Map(),
    addEventListener(type, listener) {
      this.listeners.set(type, [...(this.listeners.get(type) || []), listener]);
    },
    removeEventListener(type, listener) {
      this.listeners.set(type, (this.listeners.get(type) || []).filter((entry) => entry !== listener));
    },
    dispatch(type) {
      (this.listeners.get(type) || []).forEach((listener) => listener());
    }
  };
}

test("every hour resolves to one of three discrete dayparts", () => {
  const seen = new Set();

  for (let hour = 0; hour < 24; hour += 1) seen.add(resolveDaypart(at(hour)));

  assert.deepEqual([...seen].sort(), ["day", "night", "twilight"]);
});

test("daypart boundaries are exact", () => {
  assert.equal(resolveDaypart(at(5, 59)), "night");
  assert.equal(resolveDaypart(at(6, 0)), "twilight");
  assert.equal(resolveDaypart(at(8, 59)), "twilight");
  assert.equal(resolveDaypart(at(9, 0)), "day");
  assert.equal(resolveDaypart(at(17, 59)), "day");
  assert.equal(resolveDaypart(at(18, 0)), "twilight");
  assert.equal(resolveDaypart(at(22, 59)), "twilight");
  assert.equal(resolveDaypart(at(23, 0)), "night");
});

test("the resolved daypart lands on the document element", () => {
  const document = fakeDocument();

  assert.equal(applyDaypart(document, { now: () => at(2) }), "night");
  assert.equal(document.documentElement.dataset.daypart, "night");
});

test("an override pins the daypart so a defect stays reproducible", () => {
  const document = fakeDocument();

  assert.equal(applyDaypart(document, { override: "day", now: () => at(2) }), "day");
  assert.equal(document.documentElement.dataset.daypart, "day");
});

test("an unknown override is ignored rather than written through", () => {
  const document = fakeDocument();

  assert.equal(applyDaypart(document, { override: "midnight", now: () => at(12) }), "day");
  assert.equal(document.documentElement.dataset.daypart, "day");
});

test("returning to a visible session re-resolves the daypart", () => {
  const document = fakeDocument();
  let hour = 17;

  applyDaypart(document, { now: () => at(hour) });
  assert.equal(document.documentElement.dataset.daypart, "day");

  observeDaypart(document, { now: () => at(hour) });
  hour = 23;
  document.dispatch("visibilitychange");

  assert.equal(document.documentElement.dataset.daypart, "night");
});

test("a hidden session is not re-resolved", () => {
  const document = fakeDocument("hidden");

  document.documentElement.dataset.daypart = "day";
  observeDaypart(document, { now: () => at(23) });
  document.dispatch("visibilitychange");

  assert.equal(document.documentElement.dataset.daypart, "day");
});

test("observation can be stopped", () => {
  const document = fakeDocument();
  const stop = observeDaypart(document, { now: () => at(23) });

  stop();
  document.dispatch("visibilitychange");

  assert.equal(document.documentElement.dataset.daypart, undefined);
});
