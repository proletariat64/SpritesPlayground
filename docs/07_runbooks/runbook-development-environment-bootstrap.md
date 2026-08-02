---
title: "Development Environment Bootstrap Runbook"
doc_type: "runbook"
status: "review"
owner: "coding-agent"
source: "chat"
created: "2026-08-01"
updated: "2026-08-02"
related_issue: ""
related_pr: ""
supersedes: "docs/90_archive/2026/06/archived-20260622-development-guide.md environment dependency instructions"
---

# Development Environment Bootstrap Runbook

## Prerequisites

Install Python 3, `uv`, Pi, and Godot `4.7.stable.official.5b4e0cb0f` on `PATH`. The bootstrap verifies Godot but does not install system software or request administrator access.

## Ensure a Checkout

```bash
python3 scripts/bootstrap_dev.py
```

The command checks every component first. Healthy add-ons, code-review-graph, and Pi packages are skipped without downloading. Missing or damaged add-ons are restored from pinned release artifacts, code-review-graph is repaired through `uv tool install`, missing Pi packages are installed from pinned sources with `pi install`, and then Godot runs a headless editor import.

## Verify Without Changes

```bash
python3 scripts/bootstrap_dev.py --check
```

Use this before development or review when installation changes are not wanted.

## Reuse Existing Archives

```bash
python3 scripts/bootstrap_dev.py \
  --limboai-archive /path/to/limboai.zip \
  --godot-ai-archive /path/to/godot-ai-plugin.zip
```

Only the exact pinned archives are accepted; SHA-256 mismatches fail before extraction.

## Force Dependency Repair

```bash
python3 scripts/bootstrap_dev.py --repair
```

This deliberately reinstalls both add-ons and code-review-graph. To avoid add-on downloads, combine `--repair` with both archive arguments.

## Skip Optional Stages

Skip the Godot editor import:

```bash
python3 scripts/bootstrap_dev.py --skip-import
```

Isolate Godot/add-on checks from code-review-graph or external Pi package checks:

```bash
python3 scripts/bootstrap_dev.py --skip-code-review-graph
python3 scripts/bootstrap_dev.py --skip-pi
```

## Code Intelligence

The pinned CLI version is recorded in `dependencies/code_review_graph.lock.json`:

```bash
python3 scripts/install_code_review_graph.py --check
python3 scripts/install_code_review_graph.py
code-review-graph build
```

Use code-review-graph instead of GitNexus for this repository. Version 2.3.7 recognizes GDScript directly and indexes `.gd` classes, functions, `extends` dependencies, and calls. The graph database under `.code-review-graph/` contains local paths and structural metadata and must not be committed. Follow `AGENTS.md` for search, caller, impact, and pre-handoff change-detection commands.

## Pi Environment

External package versions and the pinned `my-pi-setup` Git commit are recorded in `dependencies/pi_packages.lock.json`:

```bash
python3 scripts/install_pi_packages.py --check
python3 scripts/install_pi_packages.py
```

The installer accepts already healthy global or project installations and calls `pi install` only for missing/mismatched entries. `AGENTS.md`, `.pi/settings.json`, and `.pi/skills/` are project source. Do not commit `auth.json`, API keys, OAuth tokens, sessions, `.pi/npm/`, or `.pi/git/`.

## Dependency Roles

- LimboAI 1.8.0 is required by development, tests, and exported game runtime.
- Godot AI 3.0.7 is required for development, debugging, and UAT only. Its export plugin must remove `_mcp_game_helper` from exported settings.
- code-review-graph 2.3.7 is a development-only code intelligence dependency.
- External Pi packages and extensions support development automation but are not application runtime dependencies.
- `addons/limboai/`, `addons/godot_ai/`, `.code-review-graph/`, `.pi/npm/`, and `.pi/git/` are local installations and must remain ignored and untracked.

## Updating a Pin

1. Review the upstream release and license.
2. Update the appropriate file under `dependencies/`, including the release-published SHA-256 digest.
3. Update the PRD, BDD, ADR, and this runbook when policy changes.
4. Run the automated CLI tests and local integration check.
5. Review the diff before downloading or installing the new artifact.

## Troubleshooting

- Godot mismatch: install the exact pinned build and confirm `godot --version`.
- Add-on mismatch: rerun with `--repair` and a known pinned archive when available.
- Checksum mismatch: discard the archive; do not bypass verification.
- Godot AI export-strip failure: do not export or ship until the pinned add-on is repaired.
- code-review-graph mismatch: review `dependencies/code_review_graph.lock.json`, then run `python3 scripts/install_code_review_graph.py`; do not commit `.code-review-graph/`.
- Pi package mismatch: review `dependencies/pi_packages.lock.json`, then run the package installer; do not copy third-party package trees into the repository.
