---
name: test-driven-development
description: "Test-first RED-GREEN-REFACTOR discipline. Use when: adding or changing behavior that tests can pin, writing tests, tempted to write code first and test after."
argument-hint: "Describe the feature or bugfix to implement test-first"
---

# Test-Driven Development

Write a failing test before any production code, make it pass with the least code possible, then refactor — never the other way around.

## Iron Law

No production code without a failing test written first. If code exists before its test, delete it and restart — do not keep it around "for reference".

## RED-GREEN-REFACTOR

1. **RED** — write one minimal test for the next small behavior.
2. Run it and confirm it fails **because the feature is missing** — not from a typo or setup error. If it passes immediately, it is testing existing behavior; rewrite it.
3. **GREEN** — write the least production code that makes the test pass.
4. Run the tests for the code you touched: everything green, output clean (the full suite runs once before landing, per finish-branch).
5. **REFACTOR** — clean up while staying green; add no new behavior (refactoring covers the steps).
6. Pick the next behavior and repeat.

## Good Tests

- One behavior per test, so a failure pinpoints one thing.
- Name states what broke when it fails.
- Exercise real code, not mocks of the thing under test.
- Assert behavior, not implementation details.

## Exceptions

Throwaway prototypes, generated code, and pure configuration may skip TDD: attended, ask the user once; unattended, record the skip in your report and proceed.
