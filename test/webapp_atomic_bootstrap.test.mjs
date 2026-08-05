import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const index = readFileSync(new URL("../webapp/index.html", import.meta.url), "utf8");
const app = readFileSync(new URL("../webapp/app.js", import.meta.url), "utf8");
const bootstrapStyles = readFileSync(new URL("../webapp/bootstrap.css", import.meta.url), "utf8");

test("keeps the application hidden until role workspaces and navigation are ready", () => {
  assert.match(index, /<body class="app-booting" aria-busy="true">/);
  assert.match(index, /id="bootstrap-shell"/);
  assert.match(index, /href="\.\/bootstrap\.css"/);
  assert.match(bootstrapStyles, /body\.app-booting > :not\(#bootstrap-shell\):not\(script\)/);
  assert.match(app, /mountWorkspaceNavigation/);
  assert.match(app, /revealApplication\(\);\n}/);
  assert.ok(app.indexOf("mountWorkspaceNavigation") < app.indexOf("revealApplication();\n}"));
});

test("keeps the atomic shell visible and marks it as failed when startup exhausts retries", () => {
  assert.match(app, /start\(\)\.catch/);
  assert.match(app, /node\.dataset\.error = error \? "true" : "false"/);
  assert.match(app, /Could not load\. Reopen the app\./);
  assert.doesNotMatch(app, /start\(\)\.catch[\s\S]*revealApplication\(\)/);
});
