const POLL_INTERVAL_MS = 250;
const POLL_ATTEMPTS = 40;

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function messages(locale) {
  const language = String(locale || "en").toLowerCase().split(/[-_]/, 1)[0];
  return ({
    uk: {
      unavailable: "Вибір контакту недоступний у цій версії Telegram.",
      expired: "Час вибору одержувача минув. Спробуйте ще раз.",
      username: "Обраний користувач не має Telegram username. Оберіть іншого одержувача.",
      timeout: "Telegram ще не передав обраного одержувача. Спробуйте ще раз."
    },
    ru: {
      unavailable: "Выбор контакта недоступен в этой версии Telegram.",
      expired: "Время выбора получателя истекло. Попробуйте ещё раз.",
      username: "У выбранного пользователя нет Telegram username. Выберите другого получателя.",
      timeout: "Telegram ещё не передал выбранного получателя. Попробуйте ещё раз."
    },
    en: {
      unavailable: "Recipient selection is unavailable in this Telegram version.",
      expired: "Recipient selection expired. Try again.",
      username: "The selected user has no Telegram username. Choose another recipient.",
      timeout: "Telegram has not delivered the selected recipient yet. Try again."
    }
  })[language] || messages("en");
}

function requestChat(telegram, preparedId) {
  return new Promise((resolve) => {
    telegram.requestChat(preparedId, (sent) => resolve(Boolean(sent)));
  });
}

export async function pickTelegramRecipient({ telegram, transport, locale }) {
  const copy = messages(locale);
  if (typeof telegram?.requestChat !== "function") throw new Error(copy.unavailable);

  const prepared = await transport.prepareRecipientPicker();
  const sent = await requestChat(telegram, prepared.prepared_id);
  if (!sent) return null;

  for (let attempt = 0; attempt < POLL_ATTEMPTS; attempt += 1) {
    const result = await transport.getRecipientPickerResult(prepared.token);
    if (result.status === "selected") {
      const recipient = result.recipient || {};
      if (!recipient.username) throw new Error(copy.username);
      return {
        userId: recipient.user_id,
        name: recipient.name || null,
        username: recipient.username
      };
    }
    if (result.status === "expired") throw new Error(copy.expired);
    await delay(POLL_INTERVAL_MS);
  }

  throw new Error(copy.timeout);
}
