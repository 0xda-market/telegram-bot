import test from "node:test";
import assert from "node:assert/strict";
import { pickTelegramRecipient } from "../webapp/adapter/recipient-picker.js";
import { createRecipientPickerTransport } from "../webapp/adapter/recipient-picker-transport.js";
import { createTelegramHost } from "../webapp/adapter/telegram-host.js";

test("host exposes recipient picker only when Telegram requestChat is available", async () => {
  const unsupported = createTelegramHost({});
  assert.equal(unsupported.pickRecipient, undefined);

  const supported = createTelegramHost(
    { requestChat() {} },
    { recipientPicker: async () => ({ username: "ada" }) }
  );
  assert.equal((await supported.pickRecipient()).username, "ada");
});

test("recipient picker transport uses the mounted webapp BFF routes", async () => {
  const requests = [];
  const transport = createRecipientPickerTransport({
    telegram: { initData: "signed" },
    apiBaseUrl: ".",
    fetchImpl: async (url, options = {}) => {
      requests.push([url, options.method || "GET"]);
      return {
        ok: true,
        status: options.method === "POST" ? 201 : 200,
        async json() {
          return options.method === "POST"
            ? { status: "ok", data: { prepared_id: "prepared-1", token: "token-1" } }
            : { data: { status: "pending" } };
        }
      };
    }
  });

  await transport.prepareRecipientPicker();
  await transport.getRecipientPickerResult("token-1");
  assert.deepEqual(requests, [
    ["./webapp/recipient-picker", "POST"],
    ["./webapp/recipient-picker/token-1", "GET"]
  ]);
});

test("native recipient picker resolves the username sent by Telegram", async () => {
  const telegram = {
    requestChat(preparedId, callback) {
      assert.equal(preparedId, "prepared-1");
      callback(true);
    }
  };
  let reads = 0;
  const transport = {
    async prepareRecipientPicker() {
      return { prepared_id: "prepared-1", token: "token-1" };
    },
    async getRecipientPickerResult(token) {
      assert.equal(token, "token-1");
      reads += 1;
      return reads === 1
        ? { status: "pending" }
        : { status: "selected", recipient: { user_id: "88", name: "Ada Lovelace", username: "ada" } };
    }
  };

  assert.deepEqual(
    await pickTelegramRecipient({ telegram, transport, locale: "en_US" }),
    { userId: "88", name: "Ada Lovelace", username: "ada" }
  );
});

test("native recipient picker keeps cancellation as a no-op", async () => {
  const telegram = { requestChat(_preparedId, callback) { callback(false); } };
  const transport = {
    async prepareRecipientPicker() { return { prepared_id: "prepared-1", token: "token-1" }; },
    async getRecipientPickerResult() { throw new Error("must not poll after cancellation"); }
  };

  assert.equal(await pickTelegramRecipient({ telegram, transport, locale: "uk_UA" }), null);
});

test("native recipient picker rejects a selected user without username", async () => {
  const telegram = { requestChat(_preparedId, callback) { callback(true); } };
  const transport = {
    async prepareRecipientPicker() { return { prepared_id: "prepared-1", token: "token-1" }; },
    async getRecipientPickerResult() {
      return { status: "selected", recipient: { user_id: "88", name: "Без Username" } };
    }
  };

  await assert.rejects(
    () => pickTelegramRecipient({ telegram, transport, locale: "uk_UA" }),
    /не має Telegram username/
  );
});
