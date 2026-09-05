---
name: verification-before-completion
description: "Evidence before assertions: run the verifying commands and read the output before declaring success. Use when: about to claim work is complete, fixed, or passing, before committing or handing off."
argument-hint: "State the claim to verify and the commands that would prove it"
---

# Verification Before Completion

Never claim "done", "fixed", or "passing" without having just run the verifying command and read its output.

## Core Rule

Evidence before assertions. Expectation is not evidence: "it should work" and "the change looks right" prove nothing — only fresh command output does.

## Rules

- Run the actual verification (tests / build / lint / reproduction steps) and read the output before making any claim.
- Reports quote the real command and its real output, not a paraphrase of what was expected.
- Partial verification supports only partial claims — "unit tests pass" is not "everything works".
- If verification fails, fix first; claim only after it passes.
