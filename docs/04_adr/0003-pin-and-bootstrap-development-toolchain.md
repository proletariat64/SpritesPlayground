---
title: "Pin and Bootstrap the Development Toolchain"
doc_type: "adr"
status: "review"
owner: "coding-agent"
source: "chat"
created: "2026-08-01"
updated: "2026-08-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Pin and Bootstrap the Development Toolchain

## Context

SpritesPlayground depends on a specific Godot build, two Godot add-ons, and a known Pi agent environment. Ignoring third-party installation trees keeps external code out of Git, but a clean checkout then needs a deterministic way to restore the environment. Always reinstalling dependencies is slow, consumes network bandwidth, and can silently change behavior when an installer resolves a latest release.

## Decision

- Pin Godot to `4.7.stable.official.5b4e0cb0f`.
- Pin LimboAI to `1.8.0`.
- Pin Godot AI to `3.0.7`.
- Record dependency metadata and release digests under `dependencies/`.
- Keep environment operations in `scripts/` and CLI behavior tests in `tests/`.
- Pin external Pi packages and Git extension sources in `dependencies/pi_packages.lock.json`; install only missing entries through `pi install`.
- Track `AGENTS.md`, `.pi/settings.json`, and project-owned Pi skills as project source. This is an explicit project exception to Dogsquard's default treatment of agent files as local/private.
- Keep Pi authentication, tokens, sessions, caches, and third-party package installations outside Git.
- Keep packaged subagent turn-budget defaults rather than introducing project hard caps; call-time budgets remain available for exceptional tasks.
- Make bootstrap health-first and idempotent: healthy components are skipped; missing or damaged components are repaired from pinned artifacts or package sources.
- Keep LimboAI as a game/runtime dependency and Godot AI as a development-only dependency whose export plugin strips its autoload.
- Verify Godot but do not install it system-wide; mismatches require an explicit developer action.

## Consequences

- Ordinary bootstrap runs perform no dependency network access on a healthy machine.
- Updating any tool requires a reviewed lockfile change.
- Clean checkouts can use downloaded pinned archives in offline environments.
- The repository owns installers and metadata but not third-party source trees.
- Developers must install the exact Godot build separately when it is absent or mismatched.
- A clean machine can reproduce external Pi resources without committing package source or machine-specific absolute paths.
- Secret-bearing Pi state remains deliberately outside the reproducible project configuration.

## Alternatives Considered

### Resolve the latest Godot AI release on every install

Rejected because installs performed at different times would not reproduce the same environment.

### Vendor add-ons in Git

Rejected because the project does not maintain forks of LimboAI or Godot AI.

### Reinstall every dependency on every bootstrap

Rejected because it creates unnecessary downloads and destroys healthy local state.
