---
title: "Development Environment Bootstrap"
doc_type: "prd"
status: "review"
owner: "coding-agent"
source: "chat"
created: "2026-08-01"
updated: "2026-08-02"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Development Environment Bootstrap

## Purpose

A checkout must be able to verify and repair the local SpritesPlayground development environment without committing third-party add-ons or repeatedly downloading healthy dependencies.

## Requirements

- Godot must report exactly `4.7.stable.official.5b4e0cb0f`.
- LimboAI must be pinned to `1.8.0` and remain required by development, tests, and exported runtime builds.
- Godot AI must be pinned to `3.0.7`, remain a development/debug/UAT dependency, and remain absent from exported game runtime behavior.
- code-review-graph must be pinned to `2.3.7`, installed as an isolated `uv tool`, and used instead of GitNexus because its built-in GDScript parser provides symbol- and call-level coverage for `.gd` files.
- Dependency versions, sources, and published SHA-256 values must be stored under `dependencies/`.
- Operational Python commands must live under `scripts/`; their tests must live under `tests/`.
- External Pi packages and extension sources must be pinned in `dependencies/pi_packages.lock.json` and installed through `pi install`, never copied into the repository.
- Safe project-owned Pi configuration, `AGENTS.md`, and project-owned skills must be tracked; authentication, API keys, sessions, caches, and third-party package trees must remain machine-local.
- `python3 scripts/bootstrap_dev.py` must use ensure semantics: verify each component first, skip healthy components without network access, and repair only missing or damaged components.
- `python3 scripts/bootstrap_dev.py --check` must be read-only and report every failed component it can evaluate.
- `--repair` must explicitly force clean add-on reinstallation.
- Downloaded archives must be checksum verified before extraction.
- `addons/limboai/`, `addons/godot_ai/`, and generated `.code-review-graph/` data must remain ignored and untracked.
- Offline installation must accept caller-supplied pinned release archives.

## Non-goals

- Installing Godot system-wide or acquiring administrator privileges.
- Provisioning CI or a self-hosted runner.
- Vendoring third-party add-on sources.
- Supporting operating systems not used by the current project environment beyond the existing LimboAI installer capabilities.

## Acceptance Criteria

- A healthy checkout passes `python3 scripts/bootstrap_dev.py --check`.
- Default ensure succeeds when deliberately invalid archive paths are supplied for already healthy components, proving those archives were not read.
- A different Godot version fails with both expected and actual versions in the diagnostic.
- Godot AI 3.0.7 export-strip registration is verified.
- Exact code-review-graph 2.3.7 passes check mode; a missing or mismatched installation is repaired only through `uv tool install`.
- Exact installed Pi package versions and pinned Git extension sources pass check mode; missing entries are the only entries passed to `pi install`.
- Installer and bootstrap behavior tests pass without downloading release archives, code-review-graph, or Pi packages.
