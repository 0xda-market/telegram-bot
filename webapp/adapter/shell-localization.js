const COPY = Object.freeze({
  en: Object.freeze({
    lang: "en",
    title: "Market",
    loading: "loading",
    search: "Search",
    category: "Category",
    all: "All",
    productsLoading: "Loading all products…",
    products: "Products",
    pages: "Catalog pages",
    previous: "Previous page",
    next: "Next page",
    categories: "Categories",
    close: "Close",
    requestQuote: "Request quote"
  }),
  uk: Object.freeze({
    lang: "uk",
    title: "Маркет",
    loading: "завантаження",
    search: "Пошук",
    category: "Категорія",
    all: "Усі",
    productsLoading: "Завантаження товарів…",
    products: "Товари",
    pages: "Сторінки каталогу",
    previous: "Попередня сторінка",
    next: "Наступна сторінка",
    categories: "Категорії",
    close: "Закрити",
    requestQuote: "Отримати ціну"
  })
});

export function shellLanguage(locale) {
  return String(locale || "").trim().toLowerCase().split(/[-_]/, 1)[0] === "uk" ? "uk" : "en";
}

export function localizeTelegramShell(document, locale) {
  if (!document?.querySelector) throw new TypeError("document is required");
  const copy = COPY[shellLanguage(locale)];
  document.documentElement?.setAttribute?.("lang", copy.lang);

  const text = (selector, value) => {
    const node = document.querySelector(selector);
    if (node) node.textContent = value;
    return node;
  };
  const attribute = (selector, name, value) => document.querySelector(selector)?.setAttribute?.(name, value);

  text("#market-title", copy.title);
  text("#snapshot", copy.loading);
  const search = document.querySelector("#search");
  if (search) search.placeholder = copy.search;
  attribute("#search", "aria-label", copy.search);
  const category = document.querySelector("#category");
  category?.children?.[0] && (category.children[0].textContent = copy.all);
  attribute("#category", "aria-label", copy.category);
  text("#status", copy.productsLoading);
  attribute("#products", "aria-label", copy.products);
  attribute(".navigation", "aria-label", copy.pages);
  attribute("#previous", "aria-label", copy.previous);
  attribute("#next", "aria-label", copy.next);
  text("#home", copy.categories);
  attribute("#close-dialog", "aria-label", copy.close);
  text("#checkout-action", copy.requestQuote);
  return copy.lang;
}
