// A lexical guardrail, not a sandbox: reads only the command text, falls open on its own errors.
import { realpathSync } from "node:fs";
import os from "node:os";
import { fileURLToPath } from "node:url";

export const EVENT = "PreToolUse";
const DENY_REASON =
  "Refused by the worktree-discipline hook in ~/.copilot/hooks: the git stash is shared by every worktree of a repository, so stashing here (even 'git stash list') touches other sessions' work. Save a diff instead: git diff > /tmp/<name>.patch and git apply it later, or commit on your own branch.";
const ALLOW_REASON =
  "Allowed by the worktree-discipline hook: one plain call of a pinned script under ~/.copilot/scripts.";
// Git global options whose value is the following word.
const VALUE_OPTIONS = new Set([
  "-C",
  "-c",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--exec-path",
  "--config-env",
  "--super-prefix",
  "--attr-source",
]);

// Splits shell text into simple commands (lists of unquoted words) by POSIX lexing; a command
// substitution, even inside double quotes, is scanned as commands of its own.
function simpleCommands(src, out) {
  let words = [];
  let word = null;
  let quote = null;
  const add = (text) => (word = (word === null ? "" : word) + text);
  const endWord = () => {
    if (word !== null) words.push(word);
    word = null;
  };
  const endCommand = () => {
    endWord();
    if (words.length > 0) out.push(words);
    words = [];
  };
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (ch === "\\" && quote !== "'") {
      add(src.slice(i + 1, i + 2));
      i++;
    } else if (quote === "'") {
      if (ch === "'") quote = null;
      else add(ch);
    } else if (ch === "`" || (ch === "$" && src[i + 1] === "(")) {
      add("");
      i = substitution(src, i, out);
    } else if (quote === '"') {
      if (ch === '"') quote = null;
      else add(ch);
    } else if (ch === "'" || ch === '"') {
      quote = ch;
      add("");
    } else if (ch === " " || ch === "\t") {
      endWord();
    } else if ("\n;&|()".includes(ch)) {
      endCommand();
    } else {
      add(ch);
    }
  }
  endCommand();
  return out;
}

// Scans the command substitution opening at src[i] (`…` or $(…)) as commands of its own and
// returns the index of its closer.
function substitution(src, i, out) {
  const open = src[i] === "`" ? i + 1 : i + 2;
  let close = src.length;
  if (src[i] === "`") {
    const tick = src.indexOf("`", open);
    if (tick >= 0) close = tick;
  } else {
    let depth = 1;
    for (let k = open; k < src.length && depth > 0; k++) {
      if (src[k] === "(") depth++;
      if (src[k] === ")") depth--;
      if (depth === 0) close = k;
    }
  }
  simpleCommands(src.slice(open, close), out);
  return close;
}

// True when a simple command runs git's stash subcommand, whatever assignments and global options
// precede it.
function runsGitStash(words) {
  let i = 0;
  while (i < words.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i])) i++;
  const program = words[i] || "";
  if (program !== "git" && !program.endsWith("/git")) return false;
  i++;
  while (i < words.length && words[i].startsWith("-")) {
    i += VALUE_OPTIONS.has(words[i]) ? 2 : 1;
  }
  return words[i] === "stash";
}

// True when the whole command is one plain call of ~/.copilot/scripts/<name>.sh: no quoting, no
// shell metacharacters, every argument a bare path-like word.
function callsPinnedScript(command, homedir) {
  const text = command.trim();
  if (/['"\\$`;&|()<>*\n]/.test(text)) return false;
  const [script, ...args] = text.split(/[ \t]+/);
  const home = homedir.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pinned = new RegExp("^(~|" + home + ")/\\.copilot/scripts/[a-z-]+\\.sh$");
  return pinned.test(script) && args.every((arg) => /^[A-Za-z0-9._/@:=+~-]+$/.test(arg));
}

export function decide(command, homedir) {
  if (typeof command !== "string") return null;
  try {
    if (simpleCommands(command, []).some(runsGitStash)) {
      return { permissionDecision: "deny", permissionDecisionReason: DENY_REASON };
    }
    if (callsPinnedScript(command, homedir)) {
      return { permissionDecision: "allow", permissionDecisionReason: ALLOW_REASON };
    }
  } catch {
    // fail open: a guardrail's own bug must not block work
  }
  return null;
}

function main() {
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("error", () => {});
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => {
    try {
      const event = JSON.parse(input);
      if (event.tool_name !== "run_in_terminal") return;
      const decision = decide(event.tool_input.command, os.homedir());
      if (decision === null) return;
      const hookSpecificOutput = { hookEventName: EVENT, ...decision };
      process.stdout.write(JSON.stringify({ hookSpecificOutput }));
    } catch {
      // fail open: a malformed event gets no opinion
    }
  });
}

// True when this file is the process entry point, for a Node without import.meta.main.
function isEntry() {
  try {
    return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
}

const isMain = import.meta.main ?? isEntry();
if (isMain) main();
