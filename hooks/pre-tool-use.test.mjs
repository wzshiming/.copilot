import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HOOK = fileURLToPath(new URL("./pre-tool-use.mjs", import.meta.url));
const HOMEDIR = "/Users/someone";

// Imported lazily so a missing module fails each test on its own rather than the whole file.
function hook() {
  return import("./pre-tool-use.mjs");
}

async function decisionOf(command, homedir = HOMEDIR) {
  const result = (await hook()).decide(command, homedir);
  return result === null ? null : result.permissionDecision;
}

function runHook(input, env = process.env) {
  return spawnSync(process.execPath, [HOOK], { input, encoding: "utf8", env, timeout: 5000 });
}

function assertSilentExit(result) {
  assert.equal(
    result.status,
    0,
    `hook must exit 0, got ${result.status} (signal ${result.signal})`,
  );
  assert.equal(result.stderr, "", "hook must write nothing to stderr");
}

describe("decide: deny", () => {
  const denied = [
    ["git stash", "the bare command"],
    ["git stash list", "a read-only subcommand still touches the shared stash"],
    ["git -C p stash list", "-C takes a value, stash is still the first subcommand word"],
    ["cd x && git stash pop", "a later simple command after &&"],
    ["/usr/bin/git --no-pager stash", "a path ending in /git plus a valueless global option"],
    ["git -c a=b stash", "-c takes a value"],
    ["echo $(git stash list)", "a command substitution"],
    ['echo "$(git stash list)"', "a command substitution inside double quotes"],
    ["GIT_DIR=x git stash", "a leading NAME=value assignment word"],
    ["git stash > /dev/null", "a redirection after the subcommand"],
    ["echo `git stash list`", "a backtick substitution"],
  ];
  for (const [command, why] of denied) {
    test(`denies ${JSON.stringify(command)}: ${why}`, async () => {
      assert.equal(await decisionOf(command), "deny");
    });
  }

  test("denies a pinned-script call chained with git stash: deny is judged before allow", async () => {
    assert.equal(await decisionOf("~/.copilot/scripts/worktree-status.sh && git stash"), "deny");
  });

  test("the deny reason says the stash is shared and points to git diff > /tmp/", async () => {
    const result = (await hook()).decide("git stash", HOMEDIR);
    assert.ok(result, "expected a deny decision for git stash");
    assert.match(result.permissionDecisionReason, /\bshared\b/);
    assert.match(result.permissionDecisionReason, /git diff > \/tmp\//);
  });
});

describe("decide: no opinion on commands that only resemble git stash", () => {
  const ignored = [
    ["echo 'git stash'", "single quotes are literal"],
    ["grep stash f", "the program word is not git"],
    ["git status", "the subcommand is not stash"],
    ["git -C stash status", "stash is the value of -C, not the subcommand"],
    ['git commit -m "drop git stash"', "the words are inside double quotes"],
    ["git diff > /tmp/x.patch", "the recommended alternative"],
    ["gitk stash", "gitk is not git"],
    ['echo "git stash"', "double quotes without a substitution are literal"],
  ];
  for (const [command, why] of ignored) {
    test(`leaves ${JSON.stringify(command)} alone: ${why}`, async () => {
      assert.equal(await decisionOf(command), null);
    });
  }
});

describe("decide: allow", () => {
  const allowed = [
    ["~/.copilot/scripts/worktree-add.sh feat/x origin/master", "plain words"],
    [
      "~/.copilot/scripts/worktree-status.sh -C ~/.copilot --base origin/master",
      "options and a ~ path",
    ],
    [
      "~/.copilot/scripts/worktree-remove.sh fix/y --base origin/master --force-delete-branch",
      "a long flag",
    ],
    ["~/.copilot/scripts/ci-wait.sh 18 wzshiming/.copilot --deadline 20", "digits and a slash"],
    [
      `${HOMEDIR}/.copilot/scripts/worktree-status.sh -C ${HOMEDIR}/proj`,
      "the home directory spelled out",
    ],
    ["~/.copilot/scripts/worktree-status.sh", "no arguments"],
    [
      "  ~/.copilot/scripts/worktree-status.sh \t -C   ~/.copilot \t",
      "surrounding and repeated whitespace",
    ],
  ];
  for (const [command, why] of allowed) {
    test(`allows ${JSON.stringify(command)}: ${why}`, async () => {
      assert.equal(await decisionOf(command), "allow");
    });
  }

  test("the allow reason names ~/.copilot/scripts", async () => {
    const result = (await hook()).decide("~/.copilot/scripts/worktree-status.sh", HOMEDIR);
    assert.ok(result, "expected an allow decision for a pinned script");
    assert.match(result.permissionDecisionReason, /~\/\.copilot\/scripts/);
  });
});

describe("decide: no opinion on calls that are not one plain pinned-script call", () => {
  const ignored = [
    ["~/.copilot/scripts/worktree-status.sh && echo ok || echo failed", "a && / || suffix"],
    ["cd x && ~/.copilot/scripts/worktree-status.sh", "a leading cd &&"],
    ["sh ~/.copilot/scripts/x.sh", "an interpreter in front of the script"],
    ["FOO=1 ~/.copilot/scripts/x.sh", "a leading assignment word"],
    ["~/.copilot/scripts/x.sh | cat", "a pipe"],
    ['~/.copilot/scripts/x.sh "a b"', "double quotes"],
    ["~/.copilot/scripts/x.sh $HOME", "a parameter expansion"],
    ["~/.copilot/scripts/../agents/x.sh", "a .. segment escaping scripts/"],
    ["~/.copilot/.worktrees/feat/x/scripts/x.sh", "a scripts/ directory inside a worktree"],
    ["/Users/other/.copilot/scripts/x.sh", "another user's home directory"],
    ["~/.copilot/scripts/X.sh", "an uppercase script name"],
    ["~/.copilot/scripts/x.py", "an extension other than .sh"],
    ["~/.copilot/scripts/x.sh a;b", "a ; inside a word"],
    ["~/.copilot/scripts/worktree-status.sh {a,b}", "brace expansion would run the script twice"],
    ["~/.copilot/scripts/worktree-status.sh a?b", "a ? glob character"],
  ];
  for (const [command, why] of ignored) {
    test(`leaves ${JSON.stringify(command)} alone: ${why}`, async () => {
      assert.equal(await decisionOf(command), null);
    });
  }
});

describe("decide: interface", () => {
  test("returns null without throwing for a non-string command", async () => {
    const { decide } = await hook();
    assert.equal(decide(undefined, "/h"), null);
    assert.equal(decide(42, "/h"), null);
  });

  test("exports EVENT as PreToolUse", async () => {
    assert.equal((await hook()).EVENT, "PreToolUse");
  });
});

describe("CLI", () => {
  const denyInput = JSON.stringify({
    tool_name: "run_in_terminal",
    tool_input: { command: "git -C p stash list" },
  });

  test("stays silent for a tool other than run_in_terminal", () => {
    const input = JSON.stringify({
      tool_name: "read_file",
      tool_input: { filePath: "/etc/hosts" },
    });
    const result = runHook(input);
    assertSilentExit(result);
    assert.equal(result.stdout, "");
  });

  test("stays silent for the memory tool although its tool_input carries git stash", () => {
    const input = JSON.stringify({
      tool_name: "memory",
      tool_input: { command: "git stash" },
    });
    const result = runHook(input);
    assertSilentExit(result);
    assert.equal(result.stdout, "");
  });

  test("stays silent on stdin that is not JSON", () => {
    const result = runHook("git stash");
    assertSilentExit(result);
    assert.equal(result.stdout, "");
  });

  test("stays silent when tool_input is missing", () => {
    const result = runHook(JSON.stringify({ tool_name: "run_in_terminal" }));
    assertSilentExit(result);
    assert.equal(result.stdout, "");
  });

  test("stays silent on empty stdin", () => {
    const result = runHook("");
    assertSilentExit(result);
    assert.equal(result.stdout, "");
  });

  test("prints a deny envelope for git -C p stash list", () => {
    const result = runHook(denyInput);
    assertSilentExit(result);
    const { hookSpecificOutput: out } = JSON.parse(result.stdout);
    assert.equal(out.hookEventName, "PreToolUse");
    assert.equal(out.permissionDecision, "deny");
    assert.match(out.permissionDecisionReason, /\bshared\b/);
  });

  test("prints an allow envelope for a pinned script under $HOME/.copilot/scripts", () => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), "eog-pre-tool-use-"));
    try {
      const input = JSON.stringify({
        tool_name: "run_in_terminal",
        tool_input: { command: `${home}/.copilot/scripts/worktree-status.sh -C ${home}` },
      });
      const result = runHook(input, { ...process.env, HOME: home });
      assertSilentExit(result);
      const { hookSpecificOutput: out } = JSON.parse(result.stdout);
      assert.equal(out.hookEventName, "PreToolUse");
      assert.equal(out.permissionDecision, "allow");
      assert.match(out.permissionDecisionReason, /~\/\.copilot\/scripts/);
    } finally {
      fs.rmSync(home, { recursive: true, force: true });
    }
  });

  test("writes exactly one JSON document and nothing else to stdout", () => {
    const result = runHook(denyInput);
    assertSilentExit(result);
    const parsed = JSON.parse(result.stdout);
    assert.deepEqual(Object.keys(parsed), ["hookSpecificOutput"]);
    assert.deepEqual(Object.keys(parsed.hookSpecificOutput).sort(), [
      "hookEventName",
      "permissionDecision",
      "permissionDecisionReason",
    ]);
  });
});
