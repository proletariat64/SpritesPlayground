# AI + Godot MCP CI/CD Runbook (Local-first)

## 🧠 Philosophy
This project is **AI-assisted + runtime-generated Godot architecture**, where:

- Scene (`.tscn`) = minimal bootstrap shell
- GDScript = runtime system builder
- Godot AI MCP = primary control + inspection layer
- CI/CD = **local-first deterministic pipeline (NOT GitHub Actions heavy CI)**

---

## 🚨 Why local CI instead of GitHub Actions
Godot CI on GitHub Actions is unreliable because:

- Godot headless initialization is slow
- Linux CI often stalls on rendering / import pipeline
- Asset import cache is not persistent across runs
- AI workflows require fast iteration loops

👉 Therefore:

> CI runs locally, GitHub is only for versioning + PR tracking

---

## 🏗 System Architecture

```
Codex / AI Agent
      ↓
Local CI Runner (Godot Headless)
      ↓
Test + Validation + MCP Inspection
      ↓
Git Commit / PR
      ↓
GitHub (source of truth)
```

---

## 🧪 Local CI Pipeline Stages

### Stage 1 — Format & Static Validation
- GDScript syntax check
- Scene file integrity check
- Missing script references

Command (example):
```bash
godot4 --headless --quit --check-only
```

---

### Stage 2 — Project Import Warmup
Force deterministic import cache:
```bash
godot4 --headless --import
```

Rules:
- Must succeed before running tests
- Cache should be reused between runs

---

### Stage 3 — Unit Tests (GdUnit4)
Run gameplay logic tests:

```bash
godot4 --headless --script res://addons/gdunit4/runtest.gd
```

Covered systems:
- CombatCharacter logic
- MoveExecutor
- StateMachine
- Spawn system

---

### Stage 4 — Runtime Simulation Test (AI MCP)
This is the key stage unique to this project:

- Launch headless runtime scene
- Attach MCP inspector
- Run scripted simulation
- Capture runtime snapshot

Outputs:
- scene tree snapshot
- character registry
- combat state summary

---

### Stage 5 — Regression Snapshot Diff
Compare:

- previous runtime state
- current runtime state

Detect:
- broken spawn logic
- missing nodes
- state machine drift

---

### Stage 6 — Optional Visual Snapshot
If runtime screenshot enabled:

- capture framebuffer
- compare hash (not pixel diff heavy)

---

## 🤖 AI (Codex) Development Rules

### ❌ Forbidden
- Direct uncontrolled `add_child()` chains in random scripts
- Hidden runtime graph construction
- Nodes not registered in runtime registry

### ✅ Required
- All runtime nodes must register to:
  - character registry
  - system registry
- All creation must go through factory functions:
  - `_spawn_character()`
  - `_create_npc()`

---

## 🧭 MCP Usage Rules
AI must prioritize MCP over code guessing:

### MCP First Workflow:
1. Inspect scene tree
2. Inspect runtime registry
3. Execute controlled mutation
4. Validate state via snapshot

---

## 🧱 Local CI Script (Recommended)
Create:

```bash
scripts/ci_local.sh
```

Pipeline:

```bash
#!/bin/bash

set -e

echo "[CI] Importing project..."
godot4 --headless --import

echo "[CI] Running tests..."
godot4 --headless --script res://addons/gdunit4/runtest.gd

echo "[CI] Running runtime simulation..."
godot4 --headless --run-tests

echo "[CI] Done"
```

---

## 📦 PR Workflow (AI-assisted)

### Step 1
AI modifies code locally

### Step 2
Run local CI:
```bash
./scripts/ci_local.sh
```

### Step 3
If pass:
```bash
git commit -am "AI change"
git push
```

### Step 4
Open PR on GitHub

---

## 🧠 Key Design Principle

> GitHub is for version control
> Godot MCP is for runtime intelligence
> Local CI is for truth verification

---

## 🚀 Future Upgrade Path

- MCP-driven test generation
- AI replay system for combat debugging
- runtime graph exporter
- deterministic simulation snapshots
- visual regression via headless rendering
