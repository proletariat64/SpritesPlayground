<!-- code-review-graph:start -->
# code-review-graph — Code Intelligence

This project uses **code-review-graph** for structural exploration, review, and change-impact analysis. It has built-in GDScript support, including `.gd` classes, functions, `extends` dependencies, and call edges.

> First use: run `code-review-graph build` from the repository root. Refresh a stale graph with `code-review-graph update --brief`; inspect health with `code-review-graph status`. Generated graph data under `.code-review-graph/` is local and must not be committed.

## Always Do

- **MUST run graph impact analysis before editing an existing symbol.** Locate the symbol with `code-review-graph search "<symbol>"`, inspect callers with `code-review-graph query callers_of "<symbol>"`, then run `code-review-graph impact --files <path> --depth 2`. Report direct callers, affected files/flows, and the blast-radius size to the user.
- **MUST refresh and review changes before committing or handing off.** Run `code-review-graph update --brief`, then `code-review-graph detect-changes --base main` to verify that only expected symbols, files, flows, and tests are affected.
- **MUST warn the user** before proceeding if code-review-graph reports HIGH/CRITICAL risk or an unexpectedly broad blast radius.
- When exploring unfamiliar code, use `code-review-graph search`, `query`, `flows`, `flow`, or `architecture` before text search. Fall back to grep/read only when the graph lacks the needed detail.
- If code-review-graph MCP tools are available, prefer their corresponding tools (`semantic_search_nodes_tool`, `query_graph_tool`, `get_impact_radius_tool`, `detect_changes_tool`, and `get_affected_flows_tool`) over CLI output.

## Never Do

- NEVER edit an existing function, class, or method without the graph preflight above.
- NEVER ignore HIGH/CRITICAL or unexpectedly broad impact results.
- NEVER rename symbols with find-and-replace; preview with `code-review-graph refactor rename --old-name <old> --new-name <new>` and apply the rename with a language-aware tool.
- NEVER commit or hand off changes without refreshing the graph and running change detection.

## CLI

| Task | Command |
| ---------- | --------- |
| Build or fully refresh the graph | `code-review-graph build` |
| Incrementally refresh and show risk | `code-review-graph update --brief` |
| Find a symbol or concept | `code-review-graph search "<query>"` |
| Inspect callers/callees/tests/imports | `code-review-graph query <pattern> "<target>"` |
| Analyze changed-file blast radius | `code-review-graph impact --files <paths...> --depth 2` |
| Review the current change set | `code-review-graph detect-changes --base main` |
| Inspect architecture and execution flows | `code-review-graph architecture`; `code-review-graph flows` |

<!-- code-review-graph:end -->

## Codex subagent workflow

Project-scoped custom roles live in `.codex/agents/`. Use them for non-trivial
ticket implementation, review, and UAT. Do not create parallel production-code
writers.

### Roles

- `spec_guardian` — turn the issue and governing PRD/spec into an acceptance map.
- `impact_mapper` — produce read-only code-review-graph impact evidence.
- `ticket_implementer` — the sole production-code writer for one ready ticket.
- `qoder_reviewer` — external semantic discovery and final gate certification.
- `regression_reviewer` — independent correctness and regression review.
- `uat_operator` — installed/runtime, input, animation, and visual evidence.

### Required orchestration

For a non-trivial implementation against an existing issue or specification:

1. Spawn `spec_guardian` and `impact_mapper` in parallel. Wait for both and
   combine their evidence into one implementation contract. Resolve any
   acceptance contradiction or HIGH/CRITICAL graph risk before editing.
2. Close the completed analysis threads, then spawn `ticket_implementer` as the
   only writer. The parent and all other subagents remain read-only while it
   writes.
3. When focused implementation checks pass, freeze the candidate and compute a
   fingerprint from tracked changes, untracked paths, and untracked contents:

   ```bash
   make fingerprint
   ```

   `scripts/candidate_fingerprint.sh` excludes Git-ignored analyzer, session,
   editor, and generated churn while retaining intended candidate files.

4. Stop all writes. Spawn `qoder_reviewer` in discovery mode and
   `regression_reviewer` in parallel against that exact fingerprint. Wait for
   both, then combine findings before asking `ticket_implementer` for one repair
   batch. Any repair creates a new candidate and invalidates prior review proof.
5. After both reviewers are clean on one unchanged candidate, run
   `qoder_reviewer` in certification mode. It runs the applicable final Makefile
   gates once and returns an exit-status table; it does not repair failures.
6. Spawn `uat_operator` when acceptance includes Godot runtime/editor behavior,
   input, animation, visual output, restart behavior, exported builds, or live
   provider work. Paid provider work always requires explicit authorization and
   a hard submission budget.

The project allows at most two open subagent threads at once. Close completed
threads before starting the next pair. Simple explanation, tiny documentation,
or obviously isolated maintenance tasks may stay single-agent unless the user
explicitly asks for the full workflow.
