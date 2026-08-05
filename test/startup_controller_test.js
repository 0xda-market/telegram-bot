import test from "node:test";
import assert from "node:assert/strict";
import { createStartupController } from "../webapp/adapter/startup-controller.js";

test("startup retries transient failures and becomes ready atomically", async () => {
  let attempts = 0;
  const phases = [];
  const controller = createStartupController({
    delays: [0, 0, 0],
    run: async () => {
      attempts += 1;
      if (attempts < 3) throw new Error("transient");
    },
    onPhase: (event) => phases.push(event.phase)
  });

  await controller.start();

  assert.equal(controller.state(), "ready");
  assert.equal(attempts, 3);
  assert.deepEqual(phases, ["attempt", "retry", "attempt", "retry", "attempt", "ready"]);
});

test("startup remains failed and reports only after retries are exhausted", async () => {
  let reported;
  const controller = createStartupController({
    delays: [0, 0],
    run: async () => { throw new Error("terminal"); },
    onFailure: async (error) => { reported = error.message; }
  });

  await assert.rejects(controller.start(), /terminal/);

  assert.equal(controller.state(), "failed");
  assert.equal(reported, "terminal");
});
