---
name: test-driven-development
description: "Discipline for writing code test-first: one failing test before any production code, RED-GREEN-REFACTOR loop, delete code written before its test. Use when: implementing a feature or bugfix, writing tests, tempted to write code first and test after."
argument-hint: "Describe the feature or bugfix to implement test-first"
---

# Test-Driven Development

Write a failing test before any production code, make it pass with the least code possible, then refactor — never the other way around.

## When to Use

- Implementing any feature or bugfix that changes behavior
- Writing or extending tests for code under development
- Tempted to write the code first and backfill tests later

## Iron Law

No production code without a failing test written first. If code exists before its test, delete it and restart — do not keep it around "for reference".

## RED-GREEN-REFACTOR

1. **RED** — write one minimal test for the next small behavior.
2. Run it and confirm it fails **because the feature is missing** — not from a typo or setup error. If it passes immediately, it is testing existing behavior; rewrite it.
3. **GREEN** — write the least production code that makes the test pass.
4. Run the full suite: everything green, output clean.
5. **REFACTOR** — clean up while staying green; add no new behavior.
6. Pick the next behavior and repeat.

## Good Tests

- One behavior per test, so a failure pinpoints one thing.
- Name states what broke when it fails.
- Exercise real code, not mocks of the thing under test.
- Assert behavior, not implementation details.

## Exceptions (require user consent)

Throwaway prototypes, generated code, and pure configuration may skip TDD — only after the user explicitly agrees.
