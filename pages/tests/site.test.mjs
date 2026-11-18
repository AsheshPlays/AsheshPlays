import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const pagesRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const projectRoot = resolve(pagesRoot, "winrar-activator");
const installUrl = "https://asheshplays.github.io/AsheshPlays/winrar-activator/Install.ps1";
const pageSource = readFileSync(resolve(projectRoot, "page.js"), "utf8");

function createPageFixture() {
  class Element {
    value = "";
    textContent = "";
    disabled = false;
    validationMessage = "";
    dataset = {};
    attributes = {};
    listeners = {};
    addEventListener(name, callback) { this.listeners[name] = callback; }
    setAttribute(name, value) { this.attributes[name] = value; }
    setCustomValidity(value) { this.validationMessage = value; }
    reportValidity() { return !this.validationMessage; }
    dispatch(name) { return this.listeners[name](); }
  }
  const ids = ["registration-name", "install-command", "command-label", "copy-command", "copy-status"];
  const elements = Object.fromEntries(ids.map(id => [id, new Element()]));
  const modes = ["install", "preview"].map(mode => Object.assign(new Element(), { dataset: { mode } }));
  let clipboard = "";
  vm.runInNewContext(pageSource, {
    document: {
      getElementById: id => elements[id],
      querySelectorAll: selector => { assert.equal(selector, "[data-mode]"); return modes; },
    },
    navigator: { clipboard: { writeText: async value => { clipboard = value; } } },
  });
  return { elements, modes, get clipboard() { return clipboard; } };
}

test("default command and clipboard use the nested Pages launcher", async () => {
  const fixture = createPageFixture();
  assert.equal(fixture.elements["install-command"].textContent, `irm ${installUrl} | iex`);
  await fixture.elements["copy-command"].dispatch("click");
  assert.equal(fixture.clipboard, `irm ${installUrl} | iex`);
  assert.equal(fixture.elements["copy-command"].textContent, "copied!");
});

test("name changes are quoted for PowerShell and survive preview mode", () => {
  const { elements, modes } = createPageFixture();
  elements["registration-name"].value = "O'Brien & Example";
  elements["registration-name"].dispatch("input");
  assert.ok(elements["install-command"].textContent.endsWith(" -Name 'O''Brien & Example'"));
  modes[1].dispatch("click");
  assert.ok(elements["install-command"].textContent.includes(" -Preview -Name 'O''Brien & Example'"));
  assert.equal(modes[1].attributes["aria-pressed"], "true");
  assert.equal(modes[0].attributes["aria-pressed"], "false");
  elements["registration-name"].value = "";
  elements["registration-name"].dispatch("input");
  assert.ok(elements["install-command"].textContent.endsWith(" -Preview"));
});

test("invalid names cannot be copied", () => {
  const { elements } = createPageFixture();
  for (const value of ["--activate", "First\nSecond"]) {
    elements["registration-name"].value = value;
    elements["registration-name"].dispatch("input");
    assert.equal(elements["copy-command"].disabled, true);
    assert.ok(elements["copy-status"].textContent.length > 0);
  }
});

test("page assets, downloads, and local navigation targets exist", () => {
  for (const relativePath of ["index.html", "winrar-activator/index.html"]) {
    const htmlPath = resolve(pagesRoot, relativePath);
    const html = readFileSync(htmlPath, "utf8");
    for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      const value = match[1];
      if (/^(?:https?:|mailto:|data:)/.test(value)) continue;
      const [pathPart, anchor] = value.split("#");
      let target = pathPart ? resolve(dirname(htmlPath), pathPart) : htmlPath;
      assert.ok(target === pagesRoot || target.startsWith(pagesRoot + sep), `Target leaves Pages: ${value}`);
      assert.ok(existsSync(target), `Missing target: ${value} in ${relativePath}`);
      if (statSync(target).isDirectory()) target = resolve(target, "index.html");
      assert.ok(existsSync(target), `Missing index: ${value}`);
      if (anchor) assert.ok(readFileSync(target, "utf8").includes(`id="${anchor}"`), `Missing anchor: ${value}`);
    }
  }
});

test("downloaded runtime and generator match the launcher digests", () => {
  const source = readFileSync(resolve(projectRoot, "Install.ps1"), "utf8");
  const packageDigest = source.match(/\$packageSha256 = '([a-f0-9]{64})'/)[1];
  const generatorDigest = source.match(/\$generatorSha256 = '([a-f0-9]{64})'/)[1];
  const sha256 = path => createHash("sha256").update(readFileSync(path)).digest("hex");
  assert.equal(sha256(resolve(projectRoot, "downloads/winrar-activator.zip")), packageDigest);
  assert.equal(sha256(resolve(projectRoot, "tools/winrar-keygen/winrar-keygen-x86.exe")), generatorDigest);
  assert.ok(source.includes("https://asheshplays.github.io/AsheshPlays/winrar-activator/downloads/winrar-activator.zip"));
  const html = readFileSync(resolve(projectRoot, "index.html"), "utf8");
  assert.ok(html.includes("🄯 Ashesh Development"));
  assert.ok(html.includes("@NaeemBolchhi"));
});
