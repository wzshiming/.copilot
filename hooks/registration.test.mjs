// node --test hooks/registration.test.mjs: the hooks registered in the agents' frontmatter against the hook files they name.
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";

const HOOKS = fileURLToPath(new URL("./", import.meta.url));
const AGENTS_DIR = fileURLToPath(new URL("../agents/", import.meta.url));
// the command names the checkout at ~/.copilot, so the file it runs is looked up beside this test
const COMMAND = /^node ~\/\.copilot\/hooks\/([a-z-]+\.mjs)$/;
// a static import's specifier, in the side-effect form or the from form
const IMPORT = /^import\s+(?:["']([^"']+)["']|[^"']*?\bfrom\s+["']([^"']+)["'])/gm;
// every agent file with the events it registers; a new agent is classified here before it passes
const AGENTS = {
  challenger: ["SubagentStart"],
  coder: ["SubagentStart"],
  detailer: ["SubagentStart"],
  examiner: ["SubagentStart"],
  executor: ["PreToolUse", "SubagentStart"],
  orchestrator: [],
  planner: [],
  reviewer: ["SubagentStart"],
  scout: ["PreToolUse", "SubagentStart"],
};
// per event: the timeout ceiling in seconds and the one function its hook exports beside EVENT
const EVENTS = {
  PreToolUse: { ceiling: 5, fn: "decide" },
  SubagentStart: { ceiling: 15, fn: "buildContext" },
};

const registrants = (event) => Object.keys(AGENTS).filter((agent) => AGENTS[agent].includes(event));

// read inside each test so a broken agent file fails every test on its own
function frontmatter(agent) {
  const file = fileURLToPath(new URL(`../agents/${agent}.agent.md`, import.meta.url));
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const end = lines.indexOf("---", 1);
  assert.ok(lines[0] === "---" && end > 0, `${agent}: no frontmatter between two --- lines`);
  return lines.slice(1, end);
}

// a top-level key's lines: its own plus the indented ones following it, or null when absent
function blockOf(lines, key) {
  const start = lines.findIndex((line) => line === `${key}:` || line.startsWith(`${key}: `));
  if (start < 0) return null;
  let end = start + 1;
  while (end < lines.length && lines[end].startsWith(" ")) end++;
  return lines.slice(start, end);
}

// a plain scalar as the agent files write them: an unquoted integer is a number, anything else text
const scalar = (text) => (text === undefined ? null : /^\d+$/.test(text) ? Number(text) : text);

// the hooks block as { [event]: { entries, lines } }, parsed in the one shape the agent files use:
// an event at indent 2, each entry a `- key: value` line at indent 4 plus `key: value` lines at
// indent 6, deeper lines belonging to the current entry; anything else is reported, not guessed at
function parseHooks(block, agent) {
  const hooks = {};
  let event = null;
  let entry = null;
  for (const line of block.slice(1)) {
    let match;
    if ((match = /^  ([A-Za-z]+):$/.exec(line))) {
      event = hooks[match[1]] = { entries: [], lines: [] };
      entry = null;
    } else if (event && (match = /^    - ([a-z]+):(?: (.*))?$/.exec(line))) {
      entry = { [match[1]]: scalar(match[2]) };
      event.entries.push(entry);
    } else if (entry && (match = /^      ([a-z]+):(?: (.*))?$/.exec(line))) {
      entry[match[1]] = scalar(match[2]);
    } else if (!(entry && line.startsWith("       "))) {
      assert.fail(`${agent}: unexpected line in the hooks block: ${JSON.stringify(line)}`);
    }
    event.lines.push(line);
  }
  return hooks;
}

function hooksOf(agent) {
  const block = blockOf(frontmatter(agent), "hooks");
  assert.ok(block, `${agent}: no hooks key`);
  return parseHooks(block, agent);
}

// an agent's registration of one event: its entries and its lines as written
function registrationOf(agent, event) {
  const registration = hooksOf(agent)[event];
  assert.ok(registration, `${agent}: ${event} is not registered`);
  return registration;
}

// the one entry an agent registers for an event
function entryOf(agent, event) {
  const { entries } = registrationOf(agent, event);
  assert.equal(entries.length, 1, `${agent}: expected one ${event} entry`);
  return entries[0];
}

// the hook file an entry's command names, as a path under hooks/
function hookOf(agent, event) {
  const match = COMMAND.exec(entryOf(agent, event).command);
  assert.ok(match, `${agent}: the ${event} command does not name a hook under ~/.copilot/hooks/`);
  return fileURLToPath(new URL(`./${match[1]}`, import.meta.url));
}

// the module namespace of the hook an entry's command names
const hookModule = (agent, event) => import(pathToFileURL(hookOf(agent, event)).href);

describe("agents/", () => {
  test("holds exactly the classified agent files", () => {
    const names = fs.readdirSync(AGENTS_DIR).filter((name) => name.endsWith(".agent.md"));
    const agents = names.map((name) => name.slice(0, -".agent.md".length));
    assert.deepEqual(agents.sort(), Object.keys(AGENTS).sort());
  });
});

describe("hooks/", () => {
  test("holds no json file", () => {
    assert.deepEqual(
      fs.readdirSync(HOOKS).filter((name) => name.endsWith(".json")),
      [],
    );
  });
});

for (const [agent, events] of Object.entries(AGENTS)) {
  describe(`${agent}.agent.md`, () => {
    if (events.length === 0) {
      test("declares no hooks key", () => {
        assert.equal(blockOf(frontmatter(agent), "hooks"), null);
      });
      return;
    }

    test(`registers exactly the events ${events.join(" and ")}`, () => {
      assert.deepEqual(Object.keys(hooksOf(agent)).sort(), [...events].sort());
    });

    test("places the hooks block right after the single-line agents key", () => {
      const lines = frontmatter(agent);
      const at = lines.findIndex((line) => /^agents: \[.*\]$/.test(line));
      assert.ok(at >= 0, "no single-line agents key");
      assert.equal(lines[at + 1], "hooks:");
    });

    for (const event of events) {
      const { ceiling } = EVENTS[event];

      describe(`${event} entry`, () => {
        test("is the only entry of its event", () => {
          assert.equal(registrationOf(agent, event).entries.length, 1);
        });

        test("carries only type, command, and timeout", () => {
          assert.deepEqual(Object.keys(entryOf(agent, event)).sort(), [
            "command",
            "timeout",
            "type",
          ]);
        });

        test("has type command", () => {
          assert.equal(entryOf(agent, event).type, "command");
        });

        test("runs node on one hook file under ~/.copilot/hooks", () => {
          assert.match(String(entryOf(agent, event).command), COMMAND);
        });

        test("names a hook file that exists in hooks/", () => {
          const file = hookOf(agent, event);
          assert.ok(fs.existsSync(file), `${file} does not exist`);
        });

        test("names the hook whose EVENT is this event", async () => {
          assert.equal((await hookModule(agent, event)).EVENT, event);
        });

        test("has a numeric timeout", () => {
          assert.equal(typeof entryOf(agent, event).timeout, "number");
        });

        test(`has a timeout of at most ${ceiling} seconds`, () => {
          const { timeout } = entryOf(agent, event);
          assert.ok(timeout <= ceiling, `timeout ${timeout} exceeds ${ceiling}`);
        });
      });
    }
  });
}

for (const [event, { fn }] of Object.entries(EVENTS)) {
  const [first, ...rest] = registrants(event);

  describe(`${event} entry across agents`, () => {
    test("is written identically in every agent registering it", () => {
      const canonical = registrationOf(first, event).lines.join("\n");
      for (const agent of rest) {
        const lines = registrationOf(agent, event).lines.join("\n");
        assert.equal(lines, canonical, `${agent} differs from ${first}`);
      }
    });
  });

  describe(`${event} hook file`, () => {
    const source = () => fs.readFileSync(hookOf(first, event), "utf8");

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
      assert.equal(typeof (await hookModule(first, event)).EVENT, "string");
    });

    test(`exports ${fn} as a function`, async () => {
      assert.equal(typeof (await hookModule(first, event))[fn], "function");
    });

    test(`exports nothing besides EVENT and ${fn}`, async () => {
      assert.deepEqual(Object.keys(await hookModule(first, event)).sort(), ["EVENT", fn].sort());
    });
  });
}
