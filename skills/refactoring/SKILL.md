---
name: refactoring
description: "Behavior-preserving restructuring in small green-to-green steps, with structural and behavioral changes committed separately. Use when: asked to refactor or clean up code, code structure makes a change hard, the REFACTOR step of TDD."
argument-hint: "Name the code to restructure and the smell or blocked change"
---

# Refactoring

Change structure, not behavior, in small named steps, each verified green before the next.

## Invariants

- Structural and behavioral changes never share a commit; a bug found mid-refactoring is noted and fixed in its own commit afterwards.
- Tests green before the first step; never refactor red.
- Untested code gets characterization tests first: pin current behavior, quirks included, as a user-approved baseline. They pass at once by design, exempt from test-driven-development's "passes at once → rewrite" rule.

## Loop

1. Name the smell and the refactoring that fixes it (Extract Function, Inline, Rename, Move, Introduce Parameter Object, …); unnamed changes are edits, not refactorings.
2. Take the smallest step that still compiles; rename, move, extract via IDE/LSP or codemods rather than by hand, then grep for stragglers in strings, docs, configs.
3. Run the touched code's tests; red → revert and take a smaller step, never debug forward.
4. Commit each green-to-green step, naming the refactoring (git-commit); no reformatting or unrelated tidying in the diff.
5. Repeat until the target smell is gone; no "while I'm here" sweeps.

## Stop Rules

- Preparatory refactoring stops once the intended change is easy; make that change in its own commit.
- Rule of three: abstract duplication at the third occurrence, not the second.
- Leave alone code slated for deletion or never to be touched again.
- Never optimize mid-refactoring: clarity now, performance later.
- Three reverts in a row: your model of the code is wrong; stop and re-read.
- Intermediate shims, a tree-wide rename alongside other changes, or multiple sessions mean a planned migration, not a refactoring: stop and get a plan approved first.

## Done

`git --no-pager diff <start-commit>` shows structure only; tests green; names reveal intent; nothing dead or half-moved remains.
