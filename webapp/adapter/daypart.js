/*
 * Daypart resolution for the Telegram shell.
 *
 * The daypart modulates material intensity and accent temperature only. It
 * never changes a surface tone, a text tone or a contrast contract, so the
 * legibility of an operational surface does not depend on the hour.
 *
 * Three discrete states rather than a continuous ramp: a discrete state can be
 * pinned, screenshotted and asserted, and a reported defect stays reproducible.
 */

const DAYPARTS = new Set(["day", "twilight", "night"]);

/**
 * `Date#getHours` is already the device's local hour, so no timezone lookup is
 * involved. A device with a wrong clock gets a wrong daypart and nothing else.
 */
export function resolveDaypart(date = new Date()) {
  const hour = date.getHours();

  if (hour >= 9 && hour < 18) return "day";
  if (hour >= 23 || hour < 6) return "night";

  return "twilight";
}

export function applyDaypart(document, { override, now = () => new Date() } = {}) {
  const daypart = DAYPARTS.has(override) ? override : resolveDaypart(now());
  document.documentElement.dataset.daypart = daypart;

  return daypart;
}

/**
 * Re-resolves when the Mini App becomes visible again, which covers a session
 * left open across a boundary without a timer or any ambient animation.
 */
export function observeDaypart(document, options = {}) {
  const listener = () => {
    if (document.visibilityState === "visible") applyDaypart(document, options);
  };

  document.addEventListener("visibilitychange", listener);

  return () => document.removeEventListener("visibilitychange", listener);
}
