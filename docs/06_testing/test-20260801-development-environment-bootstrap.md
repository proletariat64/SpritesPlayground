---
title: "Development Environment Bootstrap Test Plan"
doc_type: "test"
status: "review"
owner: "coding-agent"
source: "chat"
created: "2026-08-01"
updated: "2026-08-02"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Development Environment Bootstrap Test Plan

## Automated CLI Tests

Run:

```bash
python3 -m unittest tests/test_bootstrap_dev.py -v
```

The suite exercises public command-line seams and must verify:

- the exact Godot pin is accepted and a different version is rejected;
- pinned LimboAI and Godot AI installations pass check mode;
- healthy add-ons are skipped even when unusable archive paths are supplied;
- Godot AI installations without the export-strip contract are rejected;
- an archive with a digest different from the Godot AI lock is rejected;
- check mode reports both missing add-ons;
- exact code-review-graph 2.3.7 passes check mode and mismatches report expected and actual versions;
- a healthy code-review-graph skips `uv`, while a missing installation invokes only `uv tool install --force code-review-graph==2.3.7`;
- exact Pi package versions pass check mode and mismatches report expected and actual versions;
- healthy Pi packages skip `pi install`, while a missing package invokes it only with the pinned source.

The tests use temporary directories and fake tool executables. They must not download external dependencies or alter the checkout's installed add-ons, code-review-graph tool, graph database, or Pi environment.

## Local Integration Check

Run against the current machine:

```bash
python3 scripts/bootstrap_dev.py --check
```

Expected result: exact Godot, LimboAI 1.8.0, Godot AI 3.0.7, code-review-graph 2.3.7, pinned Pi packages, and the pinned Git extension source are reported ready.

## Regression Checks

After bootstrap/configuration changes, also run the existing runtime and AI combat smoke tests using the already installed local dependencies. Full editor import is required only when project resources or add-on installation state changed.
