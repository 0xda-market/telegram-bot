const DEFAULT_DELAYS = Object.freeze([0, 400, 1200]);

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function createStartupController({
  run,
  onPhase = () => {},
  onFailure = () => {},
  delays = DEFAULT_DELAYS
}) {
  if (typeof run !== "function") throw new TypeError("startup run operation is required");
  let state = "idle";
  let promise;

  async function start() {
    if (state === "ready") return;
    if (promise) return promise;
    promise = (async () => {
      state = "loading";
      let lastError;
      for (let attempt = 0; attempt < delays.length; attempt += 1) {
        if (delays[attempt] > 0) await wait(delays[attempt]);
        try {
          onPhase({ phase: "attempt", attempt: attempt + 1 });
          await run({ attempt: attempt + 1 });
          state = "ready";
          onPhase({ phase: "ready", attempt: attempt + 1 });
          return;
        } catch (error) {
          lastError = error;
          onPhase({ phase: "retry", attempt: attempt + 1, error });
        }
      }
      state = "failed";
      await onFailure(lastError);
      throw lastError;
    })().finally(() => {
      promise = undefined;
    });
    return promise;
  }

  return { start, state: () => state };
}
