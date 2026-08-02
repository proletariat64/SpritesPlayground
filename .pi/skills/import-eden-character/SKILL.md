---
name: import-eden-character
description: "Import a completed Eden package into SpritesPlayground as a deterministic, provenance-preserving character, optionally create an independent explicit-palette recolor, generate SpriteFrames, and verify Creator Lab and Playground consumption."
disable-model-invocation: true
---

# Import an Eden character

Use this skill only from the SpritesPlayground repository root. It orchestrates the existing importer; it does not hand-organize frames, invent missing art, or change runtime code.

## Required input

Collect these values before writing project outputs:

- `PACKAGE`: absolute or repository-relative directory containing Eden `package.json`.
- `TARGET_NAME`: user-facing target name. `tools/import_eden_character.py` deterministically derives the snake-case character identity.
- Optional recolor: an already imported `SOURCE_CHARACTER_ID`, a distinct `RECOLOR_TARGET_NAME`, and an explicit palette JSON path. The JSON must contain a stable `mapping_id` and exact `from_rgba`/`to_rgba` entries. A repository preset such as `data/recolor_presets/miduo_green_uniform_to_blue_v1.json` is valid only when the user explicitly chooses it.
- `GODOT`: use `godot` unless the environment requires `godot4` or an explicit executable.

Do not ask about facts the package or importer can determine. Ask one focused question only when proceeding would require an unsafe semantic choice:

1. `PACKAGE`, target name, recolor source, recolor target, or explicit palette/preset is absent.
2. The derived target identity already owns outputs and the user has not approved replacing that same identity.
3. A color selection, behavior substitution, action composition, or missing-art fallback would have to be guessed.
4. Validation reports unresolved semantic items that cannot safely remain unequipped.

Missing canonical art is not itself a question: preserve it as `missing`, leave dependent actions `unequipped`, and report it. Never guess a replacement behavior or broad color range. Never use `--skip-hash-verification` for a real import.

## 1. Establish a clean boundary

Keep all pre-existing work. Do not reset, clean, stage, or commit it.

```bash
PROJECT_ROOT="$PWD"
git status --short
python3 -m unittest tools.test_eden_character_import
```

Confirm the package and derive the exact identity with importer code:

```bash
PACKAGE="/absolute/path/to/package"
TARGET_NAME="Character Name"
GODOT="godot"
test -f "$PACKAGE/package.json"
CHARACTER_ID="$(python3 -c 'import sys; from tools.import_eden_character import _snake_id; print(_snake_id(sys.argv[1]))' "$TARGET_NAME")"
printf 'target_name=%s character_id=%s\n' "$TARGET_NAME" "$CHARACTER_ID"
```

Check whether any target-owned paths already exist. Derive move ownership from the target template rather than a prefix glob, because one identity may prefix another (for example `miduo` and `miduo_blue`):

```bash
for path in \
  "data/v0_6/templates/$CHARACTER_ID.json" \
  "data/v0_6/sprite_sets/$CHARACTER_ID.json" \
  "data/imports/$CHARACTER_ID" \
  "godot/assets/frames/$CHARACTER_ID" \
  "godot/resources/sprite_frames/$CHARACTER_ID.tres"; do
  test ! -e "$path" || printf 'existing target: %s\n' "$path"
done
python3 - "$CHARACTER_ID" <<'PY'
import json, sys
from pathlib import Path
cid = sys.argv[1]
template = Path("data/v0_6/templates") / f"{cid}.json"
if template.is_file():
    for move_id in json.loads(template.read_text(encoding="utf-8")).get("equipped_moves", []):
        path = Path("data/v0_6/moves") / f"{move_id}.json"
        print(path)
PY
```

If target-owned paths exist, distinguish an explicitly requested deterministic re-run from an identity collision. Continue a requested same-character re-run; otherwise ask whether to replace that identity or use a new target name. Never delete unrelated files.

## 2. Preflight the Eden package without touching the repository

Run the importer against a temporary project root. Hash verification remains enabled. This checks manifest coverage/order, exact direction-unit accounting, contiguous frames, and every declared SHA-256 before repository outputs are replaced.

```bash
PREFLIGHT_ROOT="$(mktemp -d)"
python3 tools/import_eden_character.py \
  "$PACKAGE" "$TARGET_NAME" \
  --project-root "$PREFLIGHT_ROOT" \
  --skip-spriteframes
PREFLIGHT_STATUS=$?
python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1])' "$PREFLIGHT_ROOT"
test "$PREFLIGHT_STATUS" -eq 0
```

On failure, stop. Report the exact importer error; do not repair Eden manifests, bypass hashes, rename behaviors, or partially copy art by hand.

## 3. Import and generate SpriteFrames

The normal command validates the source again, replaces only character-scoped generated outputs, copies immutable Eden provenance, writes template/sprite-set/moves/report JSON, imports textures in Godot, and generates the target `SpriteFrames` resource.

```bash
python3 tools/import_eden_character.py \
  "$PACKAGE" "$TARGET_NAME" \
  --project-root "$PROJECT_ROOT" \
  --godot "$GODOT" \
  | tee "/tmp/${CHARACTER_ID}_import_stdout.json"
```

Do not pass `--skip-spriteframes` for the final run. The expected generated areas are:

- `godot/assets/frames/<character_id>/`
- `data/imports/<character_id>/` including `eden_package.json`, behavior manifests, previews, and `import_report.json`
- `data/v0_6/templates/<character_id>.json`
- `data/v0_6/sprite_sets/<character_id>.json`
- `data/v0_6/moves/<character_id>_*.json`
- `godot/resources/sprite_frames/<character_id>.tres`

The Eden package is read-only source. Never move, rename, recolor, or edit its files.

## 4. Validate exact accounting and provenance

Run the skill checker against the same package and identity:

```bash
python3 .pi/skills/import-eden-character/scripts/validate_result.py \
  --project-root "$PROJECT_ROOT" \
  --package "$PACKAGE" \
  --character-id "$CHARACTER_ID"
```

Treat any checker error as a failed import. Its success proves package/report behavior order, behavior/direction/frame totals, manifest and frame hashes, provenance copies, composition/accounting categories, target identities, character-scoped moves, and generated `SpriteFrames` presence.

Read the report and explicitly surface every category, including empty arrays:

```bash
python3 - "$CHARACTER_ID" <<'PY'
import json, sys
from pathlib import Path
cid = sys.argv[1]
p = Path("data/imports") / cid / "import_report.json"
r = json.loads(p.read_text(encoding="utf-8"))
print(json.dumps({
    "status": r["status"],
    "character_id": r["character_id"],
    "source_accounting": r["source_accounting"],
    "imported": r["imported"],
    "composed": r["composed"],
    "defaulted": r["defaulted"],
    "missing": r["missing"],
    "unequipped": r["unequipped"],
    "unresolved": r["unresolved"],
    "equipped_actions": r["equipped_actions"],
    "outputs": r["outputs"],
}, indent=2))
PY
```

Do not silently turn a `missing`, `unequipped`, or `unresolved` item into imported/composed/defaulted content. Continue with honest missing/unequipped entries when `unresolved` is empty. If `unresolved` is non-empty, stop before manual edits and ask only for the specific unsafe semantic decision.

## 5. Optional independent recolor

Recolor is a separate operation after the source import passes. It requires an explicit source identity, distinct target identity, and exact palette document. Do not derive a palette from a color description. Do not reuse the source identity.

```bash
SOURCE_CHARACTER_ID="$CHARACTER_ID"
RECOLOR_TARGET_NAME="Character Name Blue"
PALETTE_MAPPING="data/recolor_presets/explicit_preset.json"
RECOLOR_ID="$(python3 -c 'import sys; from tools.import_eden_character import _snake_id; print(_snake_id(sys.argv[1]))' "$RECOLOR_TARGET_NAME")"
test "$RECOLOR_ID" != "$SOURCE_CHARACTER_ID"
python3 - "$PALETTE_MAPPING" "$SOURCE_CHARACTER_ID" "$RECOLOR_ID" <<'PY'
import json, sys
p, source, target = sys.argv[1:]
d = json.load(open(p, encoding="utf-8"))
assert d.get("mapping_id"), "palette requires mapping_id"
assert d.get("entries"), "palette requires entries"
assert source != target, "recolor target must be independent"
for row in d["entries"]:
    a, b = row["from_rgba"], row["to_rgba"]
    assert len(a) == len(b) == 4 and a[3] == b[3], "exact RGBA entries must preserve alpha"
print(f'palette={d["mapping_id"]} entries={len(d["entries"])} source={source} target={target}')
PY
```

Check target collision as in step 1, then run:

```bash
python3 tools/import_eden_character.py \
  "$RECOLOR_TARGET_NAME" \
  --project-root "$PROJECT_ROOT" \
  --recolor-from "$SOURCE_CHARACTER_ID" \
  --palette-mapping "$PALETTE_MAPPING" \
  --godot "$GODOT" \
  | tee "/tmp/${RECOLOR_ID}_recolor_stdout.json"

python3 .pi/skills/import-eden-character/scripts/validate_result.py \
  --project-root "$PROJECT_ROOT" \
  --package "$PACKAGE" \
  --character-id "$RECOLOR_ID" \
  --source-character-id "$SOURCE_CHARACTER_ID"
```

The recolor must have its own frames, template, sprite set, character-scoped moves, report, palette provenance, and SpriteFrames. The checker compares every target pixel with the source plus exact mapping and verifies the current source import report hash. Report `mapping_id`, mapping entries, recolored pixels, inherited accounting, missing/unequipped/unresolved items, and target outputs. Never edit the source character to make the variant work.

## 6. Focused checks

Run the generic data validator and generated-resource checker for every new identity. Bootstrap an isolated development environment first so transitive schema dependencies such as `referencing` are present; do not modify the system interpreter:

```bash
VENV="${VENV:-.venv}"
python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install -r requirements-dev.txt
"$VENV/bin/python" tools/validate_prd_v0_3.py
godot --headless --path . --script tools/generate_imported_spriteframes.gd -- "$CHARACTER_ID"
```

For the repository's known Miduo base/recolor fixtures, also run the focused public seams when applicable:

```bash
godot --headless --path . --script tools/miduo_import_smoke.gd
godot --headless --path . --script tools/miduo_recolor_smoke.gd
```

Use `godot4` instead of `godot` consistently if that is the selected executable. Do not claim a character-specific smoke covers a different identity.

## 7. Creator Lab and Playground verification

1. Launch with `godot --path . --editor` or `godot --path .` and open the project.
2. In Playground press `C` to open Creator Lab v0.3. Select the imported target. Confirm template identity, sprite-set identity, HP/defaults, equipped move mapping, wardrobe coverage, and generated animation preview.
3. Save/apply, then use Creator Lab's roundtrip/reload check. Confirm save/reload exactness and `SpriteFrames generated` status.
4. Return to Playground. Exercise idle, eight-direction walk/run, dash, jump, `J` jab, `K` kick, facing changes, hurt/knockdown/dead, and the unequipped-action safe no-op where relevant. For a recolor, spawn/select both identities and confirm edits to one do not alter the other.
5. Press `R` to reset Playground after each trial. If cached resources look stale, close the running scene, rerun `godot --headless --editor --path . --quit`, regenerate with `tools/generate_imported_spriteframes.gd`, and retry. Do not patch generated `.tres` or frame paths manually.

For the known Miduo visual fixture, optional screenshot UAT is:

```bash
godot --path . --script tools/miduo_visual_uat.gd
```

## Failure and re-run rules

- Source/package/hash/accounting failure: make no repository repair; fix/re-export the Eden package, then restart at preflight.
- Importer failure after output replacement: preserve logs and `git status`; correct only the reported input/environment problem and rerun the identical full command. The importer deterministically replaces only that identity's frames/provenance/data and stale character-scoped moves.
- SpriteFrames-only failure: after fixing Godot import/environment, run `godot --headless --editor --path . --quit`, then `godot --headless --path . --script tools/generate_imported_spriteframes.gd -- <character_id>` and rerun the checker.
- Recolor unused-color or zero-change failure: correct the explicit palette with the user, then rerun the same independent target. Never broaden selection automatically.
- Validation/runtime failure: do not substitute behaviors or hand-edit generated data. Report the failed command and first actionable diagnostic.
- Before finishing, compare `git status --short` with the initial snapshot. Leave all changes uncommitted and unstaged.

## Completion report

Give concise evidence:

- target name/identity and optional recolor source, target, and `mapping_id`
- exact behavior, direction-unit, and frame totals
- imported/composed/defaulted/missing/unequipped/unresolved lists (empty lists included)
- generated output paths and provenance/checker result
- focused commands with pass/fail/skip and manual Creator Lab/Playground result
- pre-existing changes preserved, newly changed files, no staged files, and any residual risk
