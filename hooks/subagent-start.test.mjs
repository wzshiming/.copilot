// node --test hooks/subagent-start.test.mjs: the SubagentStart hook, buildContext and its CLI.
import { test, describe, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync, execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HOOK = fileURLToPath(new URL("./subagent-start.mjs", import.meta.url));
const SCRIPT = fileURLToPath(new URL("../scripts/worktree-status.sh", import.meta.url));
const BUDGET = 4096;

const header = (cwd) =>
  `Worktrees of the repository containing ${cwd}, listed by worktree-status.sh when this subagent started:`;
const FIELDS =
  "Fields: <path>  <branch>|detached@<sha7>  main|linked  clean|dirty:<N>  merged|unmerged(<base>)|nobase.";
const GUIDANCE =
  "The main line is the user's own checkout and belongs to other sessions: no checkout, switch, or stash happens there. Dispatched work happens in the linked worktree the brief names, or in one the dispatcher creates. orphan: lines are unregistered leftovers under .worktrees and prunable: lines are registrations whose directory is gone; the dispatcher handles both, this subagent deletes neither. The stash is shared by every worktree.";
const MAIN_LINE = "/r  master  main  clean  merged";
const LINKED_LINE = "/r/.worktrees/feat  feat  linked  clean  merged";

// imported inside each test so a missing module fails every test on its own
const load = () => import("./subagent-start.mjs");

// the lines between the header and the Fields line, and the Fields line onwards
function listSection(text) {
  assert.equal(typeof text, "string", "buildContext returned no text");
  const lines = text.split("\n");
  const fieldsAt = lines.indexOf(FIELDS);
  assert.notEqual(fieldsAt, -1, "no Fields: line");
  return { list: lines.slice(1, fieldsAt), tail: lines.slice(fieldsAt) };
}

// a linked line whose path is padded with `count` copies of `filler`
function linkedLine(i, filler, count) {
  const n = String(i).padStart(2, "0");
  return `/r/.worktrees/w${n}-${filler.repeat(count)}  b${n}  linked  clean  merged`;
}

// 40 linked lines of exactly `bytes` UTF-8 bytes each, newline included
function linkedLines(bytes) {
  const count = bytes - 1 - Buffer.byteLength(linkedLine(0, "", 0));
  return Array.from({ length: 40 }, (_, i) => linkedLine(i + 1, "x", count));
}

describe("subagent-start.mjs exports", () => {
  test("EVENT is SubagentStart", async () => {
    assert.equal((await load()).EVENT, "SubagentStart");
  });

  test("buildContext returns null for empty status output", async () => {
    assert.equal((await load()).buildContext("", "/r"), null);
  });

  test("buildContext returns null for whitespace-only status output", async () => {
    assert.equal((await load()).buildContext(" \n\t\n", "/r"), null);
  });

  test("buildContext returns null when only the main line is listed", async () => {
    assert.equal((await load()).buildContext(`${MAIN_LINE}\n`, "/r"), null);
  });

  test("buildContext returns null without throwing for a non-string status output", async () => {
    const { buildContext } = await load();
    for (const bad of [undefined, null, 42, {}]) {
      assert.equal(buildContext(bad, "/r"), null);
    }
  });

  test("buildContext returns text holding a linked line verbatim", async () => {
    const text = (await load()).buildContext(`${MAIN_LINE}\n${LINKED_LINE}\n`, "/r");
    assert.equal(typeof text, "string");
    assert.ok(text.split("\n").includes(LINKED_LINE), text);
  });

  test("buildContext returns text for a lone orphan: line", async () => {
    const text = (await load()).buildContext("orphan: /r/.worktrees/x\n", "/r");
    assert.equal(typeof text, "string");
    assert.ok(text.split("\n").includes("orphan: /r/.worktrees/x"), text);
  });

  test("buildContext returns text for a lone prunable: line", async () => {
    const text = (await load()).buildContext("prunable: /r/.worktrees/y\n", "/r");
    assert.equal(typeof text, "string");
    assert.ok(text.split("\n").includes("prunable: /r/.worktrees/y"), text);
  });

  test("buildContext reads linked from the third two-space field despite single spaces in the path", async () => {
    const line = "/r/my dir/.worktrees/feat x  feat-x  linked  clean  merged";
    const text = (await load()).buildContext(
      `/r/my dir  master  main  clean  merged\n${line}\n`,
      "/r/my dir",
    );
    assert.equal(typeof text, "string");
    assert.ok(text.split("\n").includes(line), text);
  });

  test("buildContext does not take a main path containing ' linked ' for a linked worktree", async () => {
    const only = "/r/a linked b  master  main  clean  merged\n";
    assert.equal((await load()).buildContext(only, "/r/a linked b"), null);
  });

  test("buildContext opens with the header naming the given cwd", async () => {
    const text = (await load()).buildContext(`${LINKED_LINE}\n`, "/x/y");
    assert.equal(text.split("\n")[0], header("/x/y"));
  });

  test("buildContext includes the Fields line", async () => {
    const text = (await load()).buildContext(`${LINKED_LINE}\n`, "/r");
    assert.ok(text.split("\n").includes(FIELDS), text);
  });

  test("buildContext includes the guidance paragraph", async () => {
    const text = (await load()).buildContext(`${LINKED_LINE}\n`, "/r");
    assert.ok(text.split("\n").includes(GUIDANCE), text);
  });

  test("buildContext joins header, list, Fields and guidance with \\n and no trailing newline", async () => {
    const text = (await load()).buildContext(`${MAIN_LINE}\n${LINKED_LINE}\n`, "/r");
    assert.equal(text, [header("/r"), MAIN_LINE, LINKED_LINE, FIELDS, GUIDANCE].join("\n"));
  });

  test("buildContext drops blank lines and keeps the rest in order", async () => {
    const { buildContext } = await load();
    const { list } = listSection(buildContext(`\n${MAIN_LINE}\n\n${LINKED_LINE}\n\n`, "/r"));
    assert.deepEqual(list, [MAIN_LINE, LINKED_LINE]);
  });

  test("buildContext adds no +N more when the list is exactly 4096 bytes", async () => {
    const lines = linkedLines(256).slice(0, 16);
    const { list } = listSection((await load()).buildContext(`${lines.join("\n")}\n`, "/r"));
    assert.deepEqual(list, lines);
  });

  test("buildContext budgets the list in UTF-8 bytes, not characters", async () => {
    // 97 characters but 147 bytes per line: all 40 fit a character count, 27 the byte budget
    const lines = Array.from({ length: 40 }, (_, i) => linkedLine(i + 1, "é", 50));
    const per = Buffer.byteLength(`${lines[0]}\n`);
    const { list } = listSection((await load()).buildContext(`${lines.join("\n")}\n`, "/r"));
    assert.equal(list.at(-1), `+${40 - Math.floor(BUDGET / per)} more`);
  });

  describe("buildContext over budget, 40 linked lines of 200 bytes each", () => {
    const lines = linkedLines(200);
    const section = async () =>
      listSection((await load()).buildContext(`${lines.join("\n")}\n`, "/r"));

    test("keeps whole lines up to 4096 bytes and as many as fit", async () => {
      const kept = (await section()).list.slice(0, -1);
      const bytes = Buffer.byteLength(kept.map((l) => `${l}\n`).join(""));
      assert.ok(bytes <= BUDGET, `${bytes} bytes kept`);
      assert.ok(bytes + 200 > BUDGET, `${bytes} bytes kept, another line would fit`);
    });

    test("ends the list with +N more, N the lines left out", async () => {
      const { list } = await section();
      const kept = list.slice(0, -1);
      assert.deepEqual(kept, lines.slice(0, kept.length));
      assert.equal(list.at(-1), `+${40 - kept.length} more`);
    });

    test("keeps the Fields line and the guidance after the cut", async () => {
      assert.deepEqual((await section()).tail, [FIELDS, GUIDANCE]);
    });
  });
});

const GIT_ENV = { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
const haveGit = spawnSync("git", ["--version"], { stdio: "ignore" }).status === 0;

function git(args) {
  return execFileSync("git", args, {
    env: GIT_ENV,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

// worktree paths as git prints them, the main checkout first
function worktreePaths(repo) {
  return git(["-C", repo, "worktree", "list", "--porcelain"])
    .split("\n")
    .filter((l) => l.startsWith("worktree "))
    .map((l) => l.slice("worktree ".length));
}

// a bare origin seeded with one commit on master and a clone of it at <tmp>/<clone>
function fixture(clone = "main") {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "subagent-start-"));
  const origin = path.join(tmp, "origin.git");
  const seed = path.join(tmp, "seed");
  const main = path.join(tmp, clone);
  git(["init", "-q", "--bare", "-b", "master", origin]);
  git(["init", "-q", "-b", "master", seed]);
  fs.writeFileSync(path.join(seed, "README.md"), "init\n");
  git(["-C", seed, "add", "README.md"]);
  git(["-C", seed, "-c", "user.name=t", "-c", "user.email=t@x", "commit", "-q", "-m", "init"]);
  git(["-C", seed, "push", "-q", origin, "master"]);
  fs.mkdirSync(path.dirname(main), { recursive: true });
  git(["clone", "-q", origin, main]);
  return {
    main,
    mainRoot: worktreePaths(main)[0],
    cleanup: () => fs.rmSync(tmp, { recursive: true, force: true }),
  };
}

// registers <main>/.worktrees/<branch> on a new branch and returns its path as git prints it
function addLinked(fx, branch) {
  const dir = path.join(fx.main, ".worktrees", branch);
  git(["-C", fx.main, "worktree", "add", "-q", "--no-track", dir, "-b", branch]);
  return worktreePaths(fx.main).find((p) => p !== fx.mainRoot);
}

function runHook(input, { cwd, hook = HOOK } = {}) {
  return spawnSync(process.execPath, [hook], { input, encoding: "utf8", env: GIT_ENV, cwd });
}

// a run that must stay silent: nothing on stderr, exit 0, nothing on stdout
function assertSilent(r) {
  assert.equal(r.stderr, "");
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "");
}

// the parsed stdout of a run that must succeed quietly
function hookOutput(r) {
  assert.equal(r.stderr, "");
  assert.equal(r.status, 0);
  assert.notEqual(r.stdout, "", "the hook printed nothing");
  return JSON.parse(r.stdout);
}

describe(
  "subagent-start.mjs end to end",
  { skip: haveGit ? false : "git is not available" },
  () => {
    test("prints nothing for a repository with only its main checkout", (t) => {
      const fx = fixture();
      t.after(fx.cleanup);
      assertSilent(runHook(JSON.stringify({ cwd: fx.main })));
    });

    test("prints nothing outside a git repository", (t) => {
      const plain = fs.mkdtempSync(path.join(os.tmpdir(), "subagent-start-plain-"));
      t.after(() => fs.rmSync(plain, { recursive: true, force: true }));
      assertSilent(runHook(JSON.stringify({ cwd: plain })));
    });

    test("reports an unregistered leftover under .worktrees as an orphan: line", (t) => {
      const fx = fixture();
      t.after(fx.cleanup);
      const stray = path.join(fx.main, ".worktrees", "stray");
      fs.mkdirSync(stray, { recursive: true });
      fs.writeFileSync(path.join(stray, "f.txt"), "x\n");
      const { additionalContext } = hookOutput(
        runHook(JSON.stringify({ cwd: fx.main })),
      ).hookSpecificOutput;
      const orphan = `orphan: ${path.join(fx.mainRoot, ".worktrees", "stray")}`;
      assert.ok(additionalContext.split("\n").includes(orphan), additionalContext);
    });

    test("hands a cwd containing a space to worktree-status.sh whole", (t) => {
      const fx = fixture("repo with space/main");
      t.after(fx.cleanup);
      const linked = addLinked(fx, "feat/x");
      const { additionalContext } = hookOutput(
        runHook(JSON.stringify({ cwd: fx.main })),
      ).hookSpecificOutput;
      const line = additionalContext.split("\n").find((l) => l.startsWith(`${linked}  `));
      assert.ok(line && line.includes("  linked  "), additionalContext);
      assert.match(additionalContext, /belongs to other sessions/);
    });

    describe("with one linked worktree", () => {
      let fx;
      let linked;
      before(() => {
        fx = fixture();
        linked = addLinked(fx, "feat/x");
      });
      after(() => fx && fx.cleanup());
      const context = () =>
        hookOutput(runHook(JSON.stringify({ cwd: fx.main }))).hookSpecificOutput;

      test("emits hookSpecificOutput for the SubagentStart event", () => {
        assert.equal(context().hookEventName, "SubagentStart");
      });

      test("lists the linked worktree's line with its path as git prints it", () => {
        const lines = context().additionalContext.split("\n");
        const line = lines.find((l) => l.startsWith(`${linked}  `));
        assert.ok(line, `no line for ${linked} in:\n${lines.join("\n")}`);
        assert.ok(line.includes("  linked  "), line);
      });

      test("opens the context with the header naming the cwd from stdin", () => {
        assert.equal(context().additionalContext.split("\n")[0], header(fx.main));
      });

      test("closes the context with the Fields line and the guidance", () => {
        assert.deepEqual(context().additionalContext.split("\n").slice(-2), [FIELDS, GUIDANCE]);
      });

      test("passes worktree-status.sh's output and the cwd through buildContext", async () => {
        const status = execFileSync("sh", [SCRIPT, "-C", fx.main], {
          env: GIT_ENV,
          encoding: "utf8",
        });
        assert.equal(context().additionalContext, (await load()).buildContext(status, fx.main));
      });

      test("writes exactly one JSON document holding only hookSpecificOutput's two keys", () => {
        const out = hookOutput(runHook(JSON.stringify({ cwd: fx.main })));
        assert.deepEqual(Object.keys(out), ["hookSpecificOutput"]);
        assert.deepEqual(Object.keys(out.hookSpecificOutput).sort(), [
          "additionalContext",
          "hookEventName",
        ]);
      });

      test("prints nothing for non-JSON stdin even when its own cwd is such a repository", () => {
        assertSilent(runHook("not json", { cwd: fx.main }));
      });

      test("prints nothing when stdin lacks cwd", () => {
        assertSilent(runHook("{}", { cwd: fx.main }));
      });

      test("prints nothing for an empty cwd", () => {
        assertSilent(runHook(JSON.stringify({ cwd: "" }), { cwd: fx.main }));
      });

      test("prints nothing for a non-string cwd", () => {
        assertSilent(runHook(JSON.stringify({ cwd: 5 }), { cwd: fx.main }));
      });

      test("prints nothing for empty stdin", () => {
        assertSilent(runHook("", { cwd: fx.main }));
      });

      test("prints nothing when no ../scripts/worktree-status.sh sits beside the hook", (t) => {
        const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "subagent-start-copy-"));
        t.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
        fs.mkdirSync(path.join(tmp, "h"));
        const copy = path.join(tmp, "h", "subagent-start.mjs");
        fs.copyFileSync(HOOK, copy);
        assertSilent(runHook(JSON.stringify({ cwd: fx.main }), { hook: copy }));
      });
    });
  },
);
