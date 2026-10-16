// node --test hooks/worktree.test.mjs: hooks/worktree.json against the hook files it registers.
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";

const REGISTRY = fileURLToPath(new URL("./worktree.json", import.meta.url));
// the command runs from CWD, so its relative path names a file of the checkout at ~/.copilot
const CWD = "~/.copilot";
const COMMAND = /^node hooks\/([a-z-]+\.mjs)$/;
// a static import's specifier, in the side-effect form or the from form
const IMPORT = /^import\s+(?:["']([^"']+)["']|[^"']*?\bfrom\s+["']([^"']+)["'])/gm;
// per event: the timeout ceiling in seconds and the one function its hook exports beside EVENT
const EVENTS = {
  PreToolUse: { ceiling: 5, fn: "decide" },
  SubagentStart: { ceiling: 15, fn: "buildContext" },
};

// parsed inside each test so a broken registry fails every test on its own
const registry = () => JSON.parse(fs.readFileSync(REGISTRY, "utf8"));

// the one entry registered for an event
function entryOf(event) {
  const entries = registry().hooks[event];
  assert.ok(Array.isArray(entries) && entries.length === 1, `${event}: expected one entry`);
  return entries[0];
}

// the hook file an event's command names, as a path under hooks/
function hookOf(event) {
  const match = COMMAND.exec(entryOf(event).command);
  assert.ok(match, `${event}: command does not name a hook under hooks/`);
  return fileURLToPath(new URL(`./${match[1]}`, import.meta.url));
}

// the module namespace of the hook an event's command names
const hookModule = (event) => import(pathToFileURL(hookOf(event)).href);

describe("worktree.json", () => {
  test("holds exactly the top-level key hooks", () => {
    assert.deepEqual(Object.keys(registry()), ["hooks"]);
  });

  test("registers exactly the events PreToolUse and SubagentStart", () => {
    assert.deepEqual(Object.keys(registry().hooks).sort(), Object.keys(EVENTS).sort());
  });
});

for (const [event, { ceiling, fn }] of Object.entries(EVENTS)) {
  describe(`${event} entry`, () => {
    test("is the only entry of its event", () => {
      const entries = registry().hooks[event];
      assert.ok(Array.isArray(entries), `${event} must be an array of entries`);
      assert.equal(entries.length, 1);
    });

    test("has type command", () => {
      assert.equal(entryOf(event).type, "command");
    });

    test("runs node on one hook file by its path relative to the checkout", () => {
      assert.match(entryOf(event).command, COMMAND);
    });

    test("runs from the cwd ~/.copilot, where that relative path resolves", () => {
      assert.equal(entryOf(event).cwd, CWD);
    });

    test("names a hook file that exists in hooks/", () => {
      const file = hookOf(event);
      assert.ok(fs.existsSync(file), `${file} does not exist`);
    });

    test("names the hook whose EVENT is this event", async () => {
      assert.equal((await hookModule(event)).EVENT, event);
    });

    test("has a numeric timeout", () => {
      assert.equal(typeof entryOf(event).timeout, "number");
    });

    test(`has a timeout of at most ${ceiling} seconds`, () => {
      const { timeout } = entryOf(event);
      assert.ok(timeout <= ceiling, `timeout ${timeout} exceeds ${ceiling}`);
    });

    test("carries only type, command, cwd, and timeout", () => {
      assert.deepEqual(Object.keys(entryOf(event)).sort(), ["command", "cwd", "timeout", "type"]);
    });
  });

  describe(`${event} hook file`, () => {
    const source = () => fs.readFileSync(hookOf(event), "utf8");

    test("loads nothing through require", () => {
      assert.doesNotMatch(source(), /\brequire\s*\(/);
    });

    test("imports only node: built-in modules", () => {
      const specifiers = Array.from(source().matchAll(IMPORT), (m) => m[1] ?? m[2]);
      assert.ok(specifiers.length > 0, "no import statement found");
      for (const specifier of specifiers) {
        assert.match(specifier, /^node:/, `${specifier} is not a node: built-in`);
      }
    });

    test("exports EVENT as a string", async () => {
      assert.equal(typeof (await hookModule(event)).EVENT, "string");
    });

    test(`exports ${fn} as a function`, async () => {
      assert.equal(typeof (await hookModule(event))[fn], "function");
    });

    test(`exports nothing besides EVENT and ${fn}`, async () => {
      assert.deepEqual(Object.keys(await hookModule(event)).sort(), ["EVENT", fn].sort());
    });
  });
}
