---
name: systematic-debugging
description: "Four-phase root-cause debugging: reproduce, isolate, understand, then fix — with a circuit breaker after three failed fix attempts. Use when: encountering a bug, test failure, or unexpected behavior, and before proposing fixes."
argument-hint: "Describe the bug, failing test, or unexpected behavior"
---

# Systematic Debugging

Find and fix the root cause through four ordered phases instead of patching the first symptom in sight.

## Four Phases

1. **Reproduce** — build a minimal, reliable reproduction. If you can't trigger the failure on demand, you can't verify a fix.
2. **Isolate** — trace upward through the call chain from the error site to the earliest point where things go wrong. Do not stop at the line that throws.
3. **Understand** — before touching code, be able to explain why the root cause produces this exact symptom. If you can't, keep investigating.
4. **Fix** — write a failing test that captures the root cause, apply a single focused fix, then verify the test passes with no regressions. No drive-by refactors or unrelated edits.

## Circuit Breaker

Three or more failed fix attempts on the same problem means your model of it is wrong. Stop patching; return to phase 1 with the new information and re-analyze.

## Rule

Fix root causes, not symptoms. A change that silences the error without explaining it is a symptom patch.
