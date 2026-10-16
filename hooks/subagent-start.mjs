// SubagentStart hook: hands a starting subagent the worktree listing of the repository around cwd.
import { execFile } from "node:child_process";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const EVENT = "SubagentStart";
const BUDGET = 4096;
const FIELDS =
  "Fields: <path>  <branch>|detached@<sha7>  main|linked  clean|dirty:<N>  merged|unmerged(<base>)|nobase.";
const GUIDANCE =
  "The main line is the user's own checkout and belongs to other sessions: no checkout, switch, or stash happens there. Dispatched work happens in the linked worktree the brief names, or in one the dispatcher creates. orphan: lines are unregistered leftovers under .worktrees and prunable: lines are registrations whose directory is gone; the dispatcher handles both, this subagent deletes neither. The stash is shared by every worktree.";

// fields are separated by two spaces, so a single space inside a path stays within its field
function needsContext(line) {
  const fields = line.split("  ");
  return (
    (fields.length >= 3 && fields[2] === "linked") ||
    line.startsWith("orphan: ") ||
    line.startsWith("prunable: ")
  );
}

export function buildContext(statusOutput, cwd) {
  if (typeof statusOutput !== "string") return null;
  const lines = statusOutput.split("\n").filter((line) => line.trim() !== "");
  if (!lines.some(needsContext)) return null;
  const kept = [];
  let bytes = 0;
  for (const line of lines) {
    bytes += Buffer.byteLength(line) + 1; // the newline counts toward the budget
    if (bytes > BUDGET) break;
    kept.push(line);
  }
  if (kept.length < lines.length) kept.push(`+${lines.length - kept.length} more`);
  return [
    `Worktrees of the repository containing ${cwd}, listed by worktree-status.sh when this subagent started:`,
    ...kept,
    FIELDS,
    GUIDANCE,
  ].join("\n");
}

function main() {
  const chunks = [];
  process.stdin.on("error", () => {}); // fail open: a stdin error must not reach stderr
  process.stdin.on("data", (chunk) => chunks.push(chunk));
  process.stdin.on("end", () => {
    try {
      const { cwd } = JSON.parse(Buffer.concat(chunks).toString());
      if (typeof cwd !== "string" || cwd === "") return;
      const script = fileURLToPath(new URL("../scripts/worktree-status.sh", import.meta.url));
      const limits = { timeout: 5000, maxBuffer: 65536 };
      execFile("sh", [script, "-C", cwd], limits, (error, stdout) => {
        const text = error ? null : buildContext(stdout, cwd);
        if (text === null) return;
        const output = {
          hookSpecificOutput: { hookEventName: EVENT, additionalContext: text },
        };
        process.stdout.write(JSON.stringify(output));
      });
    } catch {
      // fail open: malformed stdin or an unspawnable child mean no output and exit 0
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
