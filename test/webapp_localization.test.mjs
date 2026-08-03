import test from "node:test";
import assert from "node:assert/strict";
import { localizeTelegramShell, shellLanguage } from "../webapp/adapter/shell-localization.js";

class Node {
  constructor() {
    this.textContent = "";
    this.placeholder = "";
    this.attributes = {};
    this.children = [];
  }

  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }
}

function shellDocument() {
  const selectors = [
    "#market-title", "#snapshot", "#search", "#category", "#status", "#products", ".navigation",
    "#previous", "#next", "#home", "#close-dialog", "#checkout-action"
  ];
  const nodes = Object.fromEntries(selectors.map((selector) => [selector, new Node()]));
  nodes["#category"].children.push(new Node());
  const documentElement = new Node();
  return {
    nodes,
    documentElement,
    querySelector(selector) { return nodes[selector] || null; }
  };
}

test("detects Ukrainian Telegram locale variants", () => {
  assert.equal(shellLanguage("uk"), "uk");
  assert.equal(shellLanguage("uk-UA"), "uk");
  assert.equal(shellLanguage("en-US"), "en");
  assert.equal(shellLanguage("fr"), "en");
});

test("localizes the first Telegram WebApp frame before the shared module loads", () => {
  const document = shellDocument();

  assert.equal(localizeTelegramShell(document, "uk-UA"), "uk");
  assert.equal(document.documentElement.attributes.lang, "uk");
  assert.equal(document.nodes["#market-title"].textContent, "Маркет");
  assert.equal(document.nodes["#snapshot"].textContent, "завантаження");
  assert.equal(document.nodes["#search"].placeholder, "Пошук");
  assert.equal(document.nodes["#category"].children[0].textContent, "Усі");
  assert.equal(document.nodes["#status"].textContent, "Завантаження товарів…");
  assert.equal(document.nodes["#home"].textContent, "Категорії");
  assert.equal(document.nodes["#checkout-action"].textContent, "Отримати ціну");
  assert.equal(document.nodes[".navigation"].attributes["aria-label"], "Сторінки каталогу");
});

test("keeps the static shell English for unsupported locales", () => {
  const document = shellDocument();
  localizeTelegramShell(document, "de-DE");
  assert.equal(document.nodes["#market-title"].textContent, "Market");
  assert.equal(document.nodes["#search"].placeholder, "Search");
});
