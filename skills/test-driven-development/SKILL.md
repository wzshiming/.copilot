---
name: test-driven-development
description: "Test-first RED-GREEN-REFACTOR discipline, alone or as a parallel tests/implementation pair. Use when: adding or changing behavior that tests can pin, writing tests, dispatched as one half of a pair."
argument-hint: "Describe the feature or bugfix to implement test-first"
---

# Test-Driven Development

Every behavior gets a failing test before its production code counts, the least code that makes it pass, then a refactor — never the other way around.

## Iron Law

No production code counts without a failing test written independently of it. Alone, the failing test comes first: if code exists before its test, delete it and restart — do not keep it around "for reference". In a pair, the tests half writes the tests while the implementation half codes, and nothing counts until the join runs them together; code that reaches the join without an independently written test is deleted.

## RED-GREEN-REFACTOR

1. **RED** — write one minimal test for the next small behavior.
2. Run it and confirm it fails **because the feature is missing** — not from a typo or setup error. If it passes immediately, it is testing existing behavior; rewrite it.
3. **GREEN** — write the least production code that makes the test pass.
4. Run the tests for the code you touched: everything green, output clean (the full suite runs once before landing, per finish-branch).
5. **REFACTOR** — clean up while staying green; add no new behavior (refactoring covers the steps).
6. Pick the next behavior and repeat.

## Paired Dispatch

Two agents work apart from one contract — the surface, each acceptance criterion as one observable behavior, and the file split — and neither edits the other's files or the contract; an unworkable contract is reported rather than patched around:

- Tests half: RED alone against the base — one test per behavior, each proven to fail for the missing feature, every failure naming a contract symbol or behavior, never a typo; a test that passes alone pins existing behavior and is rewritten; report a criterion-to-test map
- Implementation half: the least production code that meets the contract, built and vetted, no tests of its own
- Join: the dispatcher merges the tests into the implementation and runs them — GREEN closes the stage; red returns to the half that departed from the contract, or to the contract when both followed it
- REFACTOR: on the joined branch, green-to-green, as in the single loop

## Good Tests

- One behavior per test, so a failure pinpoints one thing.
- Name states what broke when it fails.
- Exercise real code, not mocks of the thing under test.
- Assert behavior, not implementation details.

## Exceptions

Throwaway prototypes, generated code, and pure configuration may skip TDD: attended, ask the user once; unattended, record the skip in your report and proceed.
