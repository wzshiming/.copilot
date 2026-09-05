---
name: code-review
description: "Both sides of code review: self-review the diff and run tests before requesting; treat every piece of feedback as a claim to verify before implementing. Use when: requesting a review before merge/handoff, responding to review feedback, disagreeing with a reviewer."
argument-hint: "Say whether you are requesting a review or responding to feedback, plus context"
---

# Code Review

Prepare reviews so they can be verified, and process feedback as technical claims to check — not orders to obey.

## Requesting

- Self-review the diff first: walk every file and confirm each change serves the requirement; remove leftovers.
- Verify before asking (verification-before-completion): the tests the change touched are green; the full suite only for cross-cutting changes or when the review gates landing (finish-branch).
- Give the reviewer the original requirements, acceptance criteria, and the changed-file list.

## Receiving

- Treat every comment as a technical claim to verify — check it against the code before implementing.
- If feedback is wrong, push back with evidence; never perform agreement you don't have.
- If a comment is unclear, ask instead of guessing intent.
- Address items one by one, stating for each whether it was adopted or rejected and why.
