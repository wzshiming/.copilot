---
name: planning
description: "Outline-first planning that cuts work into cohesive, loosely coupled modules with explicit dependencies, then details each module. Use when: writing or revising a plan, decomposing a multi-module change, detailing one outlined module."
argument-hint: "Name the goal to plan, or the outlined module to detail"
---

# Planning

Cut the work into modules first, align on the cut, then detail each module inside its declared contract; a plan records decisions in prose, never code.

## Size the Work

- One module (one responsibility, one file set, no contract another part of the change consumes): write the Plan in one pass, steps included — one context holds the whole change against the real code
- Several modules, or more steps than one context details well: write the Outline, align on it, then detail the modules of a wave in parallel, one detailer per module; each Module Detail stays at the functional level, and the implementer of a module derives its steps

A plan need not finish in one sitting: later waves may stay outlined and are detailed against the landed code when their turn comes.

## Module Criteria

Every module passes these before it is detailed; one that fails is re-cut in the Outline, never patched in its detail:

- Cohesion: one responsibility, statable in one sentence without "and"; code that changes together lives in one module, cut by responsibility rather than by technical layer
- Coupling: other modules depend on it only through its declared contract, phrased in the consumer's vocabulary, never by reaching into its internals; each shared type has exactly one owner, and the module is testable alone with its dependencies faked at the contract
- Dependencies: what it consumes (from which module, and what), what it produces for other modules, and the external libraries it uses, all listed; the graph is acyclic, and an undeclared dependency is a plan defect
- Design from the whole: the module restructures the existing design so the change reads as designed in from the start, never a patch bolted on (special case, flag, wrapper, duplicated path, suppressed symptom); a compatibility layer (shim, adapter, dual path) needs an explicit compatibility requirement, stated by the user or plan or established from codebase facts such as a published API or external callers, and recorded; working code is the floor, not the bar
- Tells of a bad cut: a module name that needs "and" or settles for "utils" or "common"; two modules that always change together (merge them); a cycle (extract the shared part or invert the dependency); a contract that mirrors the provider's internals (rephrase it in the consumer's terms)

## Plan

A one-module plan, under its title and TL;DR (what, why, and the recommended how):

- Steps: numbered, each restructuring the existing design to take the change rather than patching around it, with dependencies and parallelism noted, grouped into named phases when there are five or more
- Relevant files: full paths with what to modify or reuse, naming specific functions and patterns
- Verification: acceptance criteria for behavior and design fit, checked by specific tests, commands, and manual checks; review gates — the steps after which a Reviewer pass covers everything since the previous gate, one before landing by default; Challenger none by default — if proposed, name the stage and a one-line reason for user approval
- Decisions: choices, assumptions, in- and out-of-scope, and each compatibility requirement that licenses a shim, adapter, or dual path, with its source (user-stated or a codebase fact)
- Further Considerations: 1–3 open questions, each with a recommendation and options

## Outline

The first pass over a multi-module change; it ends with a request to approve the decomposition:

- Title and TL;DR: what, why, and the recommended how
- Modules: for each, its responsibility, the paths it owns, the contract it produces, what it consumes from other modules and external libraries (build-vs-reuse noted), and its status: outlined, detailed, or approved
- Order: waves from the dependency graph, foundational modules first, modules within a wave in parallel, and whether each wave lands on its own or all land together
- Review gates, Decisions, Further Considerations: as in the Plan

## Module Detail

The second pass details one module from the Outline, the module's brief, and the contracts it consumes and produces — never from other modules' details — so a wave's modules are detailed in parallel by separate detailers, each given only the Outline and its own brief. A detail says what the module does, depends on, and must hold, never how its code is written:

- Responsibility: the one thing the module does, in one sentence, and what it leaves to other modules
- Behavior: what it must do, as observable outcomes including failure handling
- Contract: what it produces for its consumers, in their vocabulary, and what it consumes — from which module or external library, and what; the paths it owns
- Constraints: invariants, compatibility requirements with their sources, limits such as performance, security, and resources, and what it must not touch
- Acceptance criteria: for behavior and design fit, including that the module depends only on what it declares, each checkable by a test, command, or manual check
- Open questions: assumptions made, questions for the user each with a recommendation, and any contract or cut change the module needs

Paths and existing symbols appear as anchors for where the module lives; edit steps, line numbers, and code belong to implementation.

## Integrate

After each wave of details comes back, integrate it before the plan is shown:

1. Coverage: every requirement maps to a behavior in some module; a requirement without a home is a missing module or a wrong cut
2. Contracts: names and semantics agree wherever two module details meet; a mismatch is fixed in the Outline's contract first, then in both details
3. Dependencies: no behavior uses anything its module does not declare, and the graph is still acyclic
4. Cut: a re-cut proposal is applied in the Outline, and the modules it touches are detailed again
5. Proportion: functional prose, no code; a detail that prescribes code is writing the code
6. Status: mark the detailed modules, name the next wave to implement, and leave later waves outlined while they wait on landed code

## Done

A one-module Plan is approved; an Outline is approved with every module of its first wave detailed, and implementation proceeds wave by wave, returning to planning at the first outlined wave.
