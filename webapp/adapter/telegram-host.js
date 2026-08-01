export function createTelegramHost(telegram = globalThis.Telegram?.WebApp) {
  return {
    initialize() {
      telegram?.ready();
      telegram?.expand?.();
      telegram?.setHeaderColor?.("secondary_bg_color");
      telegram?.setBackgroundColor?.("secondary_bg_color");
    },
    locale() {
      return telegram?.initDataUnsafe?.user?.language_code || globalThis.navigator?.language || "en";
    },
    viewport() {
      return {
        width: globalThis.innerWidth,
        height: telegram?.viewportStableHeight || globalThis.innerHeight
      };
    },
    onViewportChanged(callback) {
      telegram?.onEvent?.("viewportChanged", callback);
      globalThis.addEventListener?.("resize", callback, { passive: true });
    },
    selectionFeedback() {
      telegram?.HapticFeedback?.selectionChanged?.();
    }
  };
}
