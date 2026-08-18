# Writing Style — Sound Like a Regular Contributor

Applies to commit messages, titles, Issue and PR bodies, and follow-up comments.

## Voice

- First person, plain and direct: "I hit this while ...", "Fixed by ..."
- One line of discovery context (how you ran into the bug) beats a lecture about the codebase
- Match the repo's register: skim 2–3 recently merged PRs (`gh pr list --repo <upstream> --state merged --limit 3`) and mirror their length and tone
- Write in the project's language (usually English), even if the conversation with the user is in another language

## Length

- Default short. A one-line fix deserves a one-paragraph PR body, not five sections of prose
- The diff speaks for itself — explain _why_, don't restate the change line by line
- Titles: imperative, ≤ ~70 chars, same convention as the commit message

## Tells that read as machine-generated (avoid)

- Bullet-pointing everything, bold keywords, emoji, headings the template didn't ask for
- Boilerplate openers and filler: "This PR introduces/aims to...", "Additionally", "Furthermore", "comprehensive", "robust", "seamlessly"
- Issue body and PR body that are near-identical copies — the Issue states the problem or motivation (repro steps / use case); the PR explains the change (root cause or design, approach)
- Every checkbox ticked — only tick what is actually true
- Invented repro steps, logs, or test output — paste only real output from commands you ran; if you didn't run it, say so

## Small humanizing details

- Anchor claims in concrete facts: file/line, exact error text, version, commit hash
- Fill optional template sections with "N/A" / "NONE" instead of inventing content
- Admit real uncertainty: "not sure this is the best place for the check — happy to move it"
- Don't @-mention maintainers or request reviewers; let triage happen
