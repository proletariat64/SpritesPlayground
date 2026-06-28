---
title: New PRD Genesis
status: current-genesis
updated: 2026-06-29
tags:
  - prd
  - spritesplayground
  - genesis
  - authoring
---

# <span style="color:#6D5BD0"><u><strong>New PRD Genesis</strong></u></span>

<small><em>Genesis 2:7 — Form the body, then breathe runtime into it.</em></small><br>
<small><em>Genesis 2:19 — What the user names, the system must preserve.</em></small>

## <span style="color:#2F80A8"><u><strong>1. Product Definition</strong></u></span>

Genesis is the official user-facing scene for defining, reviewing, validating, and saving sprite characters.

Genesis is not an animation editor, not a pixel-art editor, not a Godot plugin requirement, and not a separate runtime architecture. It writes <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> JSON, reads Godot-owned animation resources through <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://</code>, validates references, and previews the same resolver contract used by runtime.

| Goal | Contract |
| --- | --- |
| User-facing authoring | Genesis is the visible scene for character setup, field editing, validation, preview, save, and smoke handoff. |
| One character, one JSON | Every character has exactly one <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> JSON record as authored truth. |
| Runtime compatibility | Saved JSON maps to [[New PRD]] world/runtime rules and [[ddd.md]] ownership. |
| Baseline content | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">origin</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">adam</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">eva</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">cain</code>, and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">solomen</code> are required default records. |
| Minimal architecture | Use one shared <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code>; do not generate per-character actor scenes in the baseline. |
| File-size boundary | Genesis design lives here so [[New PRD]] remains readable. |

## <span style="color:#2F80A8"><u><strong>2. Document Boundary</strong></u></span>

| Document | Owns | Does Not Own |
| --- | --- | --- |
| [[New PRD]] | World rules, runtime rules, combat formula, behavior catalog, implementation route. | Detailed Genesis scene flow. |
| [[ddd.md]] | Domain model, field ownership, runtime/data separation, validation invariants. | User-facing screen layout. |
| [[New PRD Genesis]] | Genesis scene, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> workflow, field editing, screen layout, baseline records, Godot handoff. | New gameplay formulas, new State/MoveData architecture, animation authoring tools. |

Rules:

- Genesis <strong><u><span style="color:#C65D5D">must not</span></u></strong> override combat, State, MoveData, SpriteSet, LifeRuntime, or VisualPresenter rules.
- Genesis may expose friendlier labels, but saved data uses canonical IDs such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch_3hit</code>.
- Genesis may generate validation reports and preview state, but the character JSON remains authored truth.
- Genesis <strong><u><span style="color:#C65D5D">must not</span></u></strong> add hidden fields to make a character work.

## <span style="color:#2F80A8"><u><strong>3. Core Operating Model</strong></u></span>

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">Genesis</span>
<span style="color:#2F80A8;font-weight:700">|-- Character Library</span>
<span style="color:#4F9D69;font-weight:500">|   |-- origin.json</span>
<span style="color:#4F9D69;font-weight:500">|   |-- adam.json</span>
<span style="color:#4F9D69;font-weight:500">|   |-- eva.json</span>
<span style="color:#4F9D69;font-weight:500">|   |-- cain.json</span>
<span style="color:#4F9D69;font-weight:500">|   `-- solomen.json</span>
<span style="color:#2F80A8;font-weight:700">|-- Definition Navigator</span>
<span style="color:#2F80A8;font-weight:700">|-- Detail Editor</span>
<span style="color:#2F80A8;font-weight:700">|-- Floating Preview Window</span>
<span style="color:#2F80A8;font-weight:700">|-- Validation Drawer</span>
<span style="color:#2F80A8;font-weight:700">|-- Rescan Bound Resources</span>
<span style="color:#2F80A8;font-weight:700">`-- Save / Reload / Playground Smoke</span>
</pre>

Genesis edits one selected <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> at a time. Shared MoveData and runtime systems remain project contracts. Character-specific truth lives in the selected JSON.

## <span style="color:#2F80A8"><u><strong>4. Godot Integration Contract</strong></u></span>

Genesis and Godot communicate through files under <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://</code>.

| Direction | File / Resource | Owner | Genesis Behavior |
| --- | --- | --- | --- |
| Genesis -> Godot | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://data/characters/{id}.json</code> | Genesis | Save <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code>; runtime reloads by <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">definition_path</code>. |
| Godot -> Genesis | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://assets/characters/{id}/...</code> | Godot / animation pipeline | Genesis rescans bound resources and updates visible coverage/validation. |
| Genesis / runtime | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code> instance with <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">definition_path</code> | Godot scene + runtime | One shared actor shell reads the selected JSON. |
| Runtime / generated | generated validation/cache files | System | Rebuildable; never source truth. |

### <span style="color:#4F9D69"><u><strong>4.1 No Godot-Side Plugin Button in Baseline</strong></u></span>

Do not add a Godot editor plugin or toolbar button yet.

Refresh rules:

- Genesis has <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Rescan Bound Resources</code>.
- Godot should observe changed files under <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://</code> through normal editor filesystem/resource reload behavior.
- If automatic reload is insufficient later, a Godot-side plugin can be considered as a future extension.
- Baseline implementation must work without a custom Godot editor plugin.

### <span style="color:#4F9D69"><u><strong>4.2 Animation Resource Boundary</strong></u></span>

Animation resources are created and tuned outside Genesis.

```md
animation software / Godot SpriteFrames editing
-> saved under res://assets/characters/{id}/...
-> Genesis Rescan Bound Resources
-> Genesis validates sprite_set.clip_coverage
-> RuntimeActor reads SpriteDefinition JSON and resolved SpriteSet coverage
```

Genesis does not create or edit animation frames. It may display animation resource facts as read-only validation evidence.

## <span style="color:#2F80A8"><u><strong>5. RuntimeActor Placement Contract</strong></u></span>

Use one shared actor scene. Do not introduce per-character actor scenes, actor-scene builders, or generated runtime scenes in the baseline.

In a level scene:

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">Playground.tscn</span>
<span style="color:#2F80A8;font-weight:700">|-- Actors</span>
<span style="color:#4F9D69;font-weight:500">|   |-- Adam : RuntimeActor.tscn instance</span>
<span style="color:#4F9D69;font-weight:500">|   |-- Cain : RuntimeActor.tscn instance</span>
<span style="color:#4F9D69;font-weight:500">|   `-- Eva  : RuntimeActor.tscn instance</span>
</pre>

Each instance differs by Godot scene placement and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">definition_path</code> only.

<code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code> must follow the current [[New PRD]] / [[ddd.md]] runtime tree:

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">RuntimeActor : CharacterBody2D</span>
<span style="color:#2F80A8;font-weight:700">|-- CollisionBody</span>
<span style="color:#4F9D69;font-weight:500">|   |-- FootCollisionShape</span>
<span style="color:#4F9D69;font-weight:500">|   `-- BodyCollisionShape</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- StateDriver : LimboHSM</span>
<span style="color:#4F9D69;font-weight:500">|   |-- idle : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   |-- walk : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   |-- jump : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   |-- fall : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   |-- attack : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   |-- hurt : BTState</span>
<span style="color:#4F9D69;font-weight:500">|   `-- dead : BTState</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- RuntimeBlackboard</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- InputSystem</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- MoveRuntime</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- CombatPorts</span>
<span style="color:#4F9D69;font-weight:500">|   |-- HitboxSource</span>
<span style="color:#4F9D69;font-weight:500">|   `-- HurtboxReceiver</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- LifeRuntime</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">`-- VisualPresenter</span>
<span style="color:#4F9D69;font-weight:500">    |-- SpriteSetPlayer</span>
<span style="color:#4F9D69;font-weight:500">    |-- HealthBars</span>
<span style="color:#4F9D69;font-weight:500">    `-- DebugOverlay</span>
</pre>

Allowed Godot scene edits:

| Godot Scene Edit | Saved Where | Sync to Genesis |
| --- | --- | --- |
| Node name | level <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">.tscn</code> | no |
| Position / transform | level <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">.tscn</code> | no |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">definition_path</code> | level <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">.tscn</code> instance property | Genesis may scan usage, but character truth stays in JSON. |
| Scene-specific spawn grouping | level <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">.tscn</code> if needed later | no baseline JSON writeback. |

Forbidden Godot scene edits:

| Field Type | Rule |
| --- | --- |
| HP / DEF / hurtboxes | Edit in Genesis JSON only. Godot display is read-only. |
| Move timing / hitboxes / ATK | Edit project MoveData / Genesis-owned character references only. |
| SpriteSet coverage | Edit in Genesis; animation resources are edited in Godot but bindings/status are validated in Genesis. |
| RuntimeBlackboard values | Runtime-only; never persisted as character truth. |

## <span style="color:#2F80A8"><u><strong>6. Screen and Layout Design</strong></u></span>

Genesis targets the project screen resolution from [[New PRD]]: <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1280x720</code>. The gameplay logical resolution remains <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">640x360</code>; Genesis UI uses the full screen resolution for readable editing.

### <span style="color:#4F9D69"><u><strong>6.1 Layout at 1280x720</strong></u></span>

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">GenesisRoot 1280x720</span>
<span style="color:#2F80A8;font-weight:700">|-- TopCommandBar        x=0   y=0   w=1280 h=48</span>
<span style="color:#2F80A8;font-weight:700">|-- MainWorkspace        x=0   y=48  w=1280 h=672</span>
<span style="color:#4F9D69;font-weight:500">|   |-- DefinitionNavigator x=0   y=48  w=300  h=672</span>
<span style="color:#4F9D69;font-weight:500">|   `-- DetailEditor        x=300 y=48  w=980  h=672</span>
<span style="color:#2F80A8;font-weight:700">|-- ValidationDrawer     x=0   y=540 w=1280 h=180 expanded / h=32 collapsed</span>
<span style="color:#2F80A8;font-weight:700">`-- FloatingPreviewWindow default w=480 h=270, min 320x180, max 640x360</span>
</pre>

Rationale:

- The old prototype's navigation/detail split is preserved as an information pattern, not copied as a fixed panel layout.
- Preview is floating and toggleable so the DetailEditor can use the screen width.
- Validation is a drawer, not a permanent right panel.
- At <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1280x720</code>, the DetailEditor must remain usable with the preview closed.

### <span style="color:#4F9D69"><u><strong>6.2 Responsive Rules</strong></u></span>

| Screen | Rule |
| --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1280x720</code> | Baseline. Navigator 300px, DetailEditor fills remaining width. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1600x900+</code> | Navigator may grow to 320px; preview may open at <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">640x360</code>. |
| below <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1280x720</code> | Supported only with scrollbars; not baseline. |
| Floating preview | Must not block save/validation controls; user can close or move it. |

### <span style="color:#4F9D69"><u><strong>6.3 Text Color Semantics</strong></u></span>

Use text color, not icon-only status, to keep the UI readable.

| Color Meaning | Text Style | Usage |
| --- | --- | --- |
| <span style="color:#2563eb"><strong>Editable</strong></span> | blue | User-editable source field. |
| <span style="color:#7c3aed"><strong>Review</strong></span> | purple | User should review; value may be derived or role-sensitive. |
| <span style="color:#64748b"><strong>Read-only</strong></span> | slate | Read-only system/source-of-truth guard. |
| <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | amber | Generated, scanned, stale, placeholder, or warning state. |
| <span style="color:#dc2626"><strong>Blocking</strong></span> | red | Blocking validation error. |
| <span style="color:#15803d"><strong>Valid</strong></span> | green | Valid/synced/pass state. |

No field should rely on color alone; labels must include clear text.

## <span style="color:#2F80A8"><u><strong>7. Surface Design</strong></u></span>

### <span style="color:#4F9D69"><u><strong>7.1 TopCommandBar</strong></u></span>

| Control | Purpose | Writes JSON |
| --- | --- | --- |
| Character selector | Select existing <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code>. | no |
| New from baseline | Clone one baseline record into a new draft. | yes, after explicit save |
| Reload JSON | Reload selected file from disk, discarding unsaved draft after confirmation. | no |
| Save JSON | Write current draft to <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://data/characters/{id}.json</code>. | yes |
| Validate | Run schema/reference/coverage checks. | no, writes report only |
| Rescan Bound Resources | Read Godot-owned resource state under <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://assets/characters/{id}/...</code>. | may update coverage status after confirmation |
| Playground Smoke | Run runtime handoff using saved JSON. | no source mutation |
| Preview Toggle | Show/hide FloatingPreviewWindow. | no character truth mutation |

### <span style="color:#4F9D69"><u><strong>7.2 DefinitionNavigator</strong></u></span>

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">Character</span>
<span style="color:#2F80A8;font-weight:700">|-- Identity</span>
<span style="color:#2F80A8;font-weight:700">|-- Size &amp; Spawn</span>
<span style="color:#2F80A8;font-weight:700">|-- Systems</span>
<span style="color:#2F80A8;font-weight:700">|-- Collision</span>
<span style="color:#2F80A8;font-weight:700">|-- Life &amp; Hurtboxes</span>
<span style="color:#2F80A8;font-weight:700">|-- Input</span>
<span style="color:#2F80A8;font-weight:700">|-- Move Loadout</span>
<span style="color:#2F80A8;font-weight:700">|-- SpriteSet Coverage</span>
<span style="color:#2F80A8;font-weight:700">|-- Interaction</span>
<span style="color:#2F80A8;font-weight:700">|-- Genesis Preferences</span>
<span style="color:#2F80A8;font-weight:700">|-- Validation</span>
<span style="color:#2F80A8;font-weight:700">`-- Raw JSON Review</span>
</pre>

Navigator rules:

- Navigator is a view over JSON groups.
- It does not define the schema.
- It shows colored status text per group: <span style="color:#15803d"><strong>Valid</strong></span>, <span style="color:#d97706"><strong>Generated/Scanned</strong></span>, <span style="color:#dc2626"><strong>Blocking</strong></span>.
- It never hides invalid groups.

### <span style="color:#4F9D69"><u><strong>7.3 DetailEditor</strong></u></span>

The DetailEditor is the only editing surface for SpriteDefinition fields.

Rules:

- Every existing SpriteDefinition field path must appear in DetailEditor or Raw JSON Review.
- Editable fields use normal controls.
- Read-only fields are visible but locked.
- DetailEditor <strong><u><span style="color:#C65D5D">must not</span></u></strong> create JSON keys outside the schema.
- If a field is missing from a loaded record, Genesis shows it as a validation issue instead of silently creating it.

### <span style="color:#4F9D69"><u><strong>7.4 FloatingPreviewWindow</strong></u></span>

| Feature | Contract |
| --- | --- |
| Default | Closed. User opens it from Preview Toggle. |
| Content | Runtime resolver preview of selected SpriteDefinition. |
| Size | Default <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">480x270</code>, max <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">640x360</code>, min <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">320x180</code>. |
| Controls | frame scrubber, action selector, facing selector, overlay toggles. |
| Overlays | foot collision, body collision, hurtboxes, hitboxes, origin anchor, health bars. |
| Truth | Preview never writes gameplay truth. |

### <span style="color:#4F9D69"><u><strong>7.5 ValidationDrawer</strong></u></span>

| Section | Shows |
| --- | --- |
| Schema | JSON parse, schema version, required fields. |
| Ownership | Genesis-owned vs Godot-owned vs runtime-only field violations. |
| Resource | rescan status, missing clips, placeholder art, stale generated data. |
| Runtime | RuntimeActor handoff, resolver parity, smoke results. |
| Baseline | five default records present and parse. |

## <span style="color:#2F80A8"><u><strong>8. DetailEditor Field Coverage Matrix</strong></u></span>

The following matrix is generated from the current baseline <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/*.json</code> field surface. It is the UI coverage contract for v1. Genesis <strong><u><span style="color:#C65D5D">must not</span></u></strong> omit these paths and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent additional SpriteDefinition fields.

| Field Path | Group | UI Status | Control | Notes |
| --- | --- | --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.body_collision.rect.h</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.body_collision.rect.w</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.body_collision.rect.x</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.body_collision.rect.y</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.foot_collision.rect.h</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.foot_collision.rect.w</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.foot_collision.rect.x</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.foot_collision.rect.y</code> | Collision | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hp_max</code> | Life / facing | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[]</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].def</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].enabled</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | toggle | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].id</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].priority</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].rect.h</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].rect.w</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].rect.x</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.hurtboxes[].rect.y</code> | Hurtboxes | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template.spawn_facing</code> | Life / facing | <span style="color:#2563eb"><strong>Editable</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">contract_refs[]</code> | System identity | <span style="color:#64748b"><strong>Read-only</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">description</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">display_name</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">equipped_systems[]</code> | Systems | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">faction</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis.editable_groups[]</code> | Genesis preferences | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis.preview_window.default_visible</code> | Genesis preferences | <span style="color:#7c3aed"><strong>Review</strong></span> | toggle | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis.preview_window.enabled</code> | Genesis preferences | <span style="color:#7c3aed"><strong>Review</strong></span> | toggle | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis.preview_window.overlays[]</code> | Genesis preferences | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis.save_policy</code> | Genesis preferences | <span style="color:#64748b"><strong>Read-only</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">id</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.bindings.attack_light</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | key binding field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.bindings.move_down</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | key binding field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.bindings.move_left</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | key binding field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.bindings.move_right</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | key binding field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.bindings.move_up</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | key binding field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.buffer.max_age_ticks</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | number field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.mode</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input.profile</code> | Input | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">interaction.default_prompt</code> | Interaction | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">interaction.enabled</code> | Interaction | <span style="color:#2563eb"><strong>Editable</strong></span> | toggle | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">interaction.hostile_targetable</code> | Interaction | <span style="color:#2563eb"><strong>Editable</strong></span> | toggle | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">interaction.modes[]</code> | Interaction | <span style="color:#2563eb"><strong>Editable</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_loadout.combo_test_move</code> | Move loadout | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_loadout.equipped_moves[]</code> | Move loadout | <span style="color:#2563eb"><strong>Editable</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_loadout.primary_attack</code> | Move loadout | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">role</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">schema_version</code> | System identity | <span style="color:#64748b"><strong>Read-only</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size.body_px[]</code> | Size | <span style="color:#64748b"><strong>Read-only</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size.frame_canvas_px[]</code> | Size | <span style="color:#64748b"><strong>Read-only</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size.origin_anchor</code> | Size | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size.size_class</code> | Size | <span style="color:#2563eb"><strong>Editable</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">source_truth</code> | System identity | <span style="color:#64748b"><strong>Read-only</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">spawn.facing</code> | Spawn default | <span style="color:#2563eb"><strong>Editable</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">spawn.initial_state</code> | Spawn default | <span style="color:#2563eb"><strong>Editable</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">spawn.position[]</code> | Spawn default | <span style="color:#2563eb"><strong>Editable</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.asset_policy</code> | SpriteSet coverage | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.authoring_fps</code> | SpriteSet coverage | <span style="color:#64748b"><strong>Read-only</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch_3hit.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch_3hit.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.basic_punch_3hit.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.dead.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.dead.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.dead.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.fall.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.fall.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.fall.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.hurt.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.hurt.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.hurt.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.idle.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.idle.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.idle.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.jump.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.jump.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.jump.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.talk.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.talk.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.talk.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.walk.policy</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | select | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.walk.required_facings[]</code> | SpriteSet coverage | <span style="color:#7c3aed"><strong>Review</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.walk.status</code> | SpriteSet coverage | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.id</code> | SpriteSet coverage | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.palette_id</code> | SpriteSet coverage | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">tier</code> | Identity | <span style="color:#2563eb"><strong>Editable</strong></span> | text field | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">validation.known_placeholders[]</code> | Validation | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">validation.required_checks[]</code> | Validation | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | array editor | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">validation.status</code> | Validation | <span style="color:#d97706"><strong>Generated/Scanned</strong></span> | status select / rescan result | Existing SpriteDefinition field; DetailEditor must show this path and <strong><u><span style="color:#C65D5D">must not</span></u></strong> invent sibling fields. |

## <span style="color:#2F80A8"><u><strong>9. SpriteDefinition JSON Contract</strong></u></span>

A <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> is the complete authored package for one character. It may reference shared project-level IDs, but it <strong><u><span style="color:#C65D5D">must not</span></u></strong> rely on hidden scene state.

### <span style="color:#4F9D69"><u><strong>9.1 Top-Level Groups</strong></u></span>

| Group | Required | Edit Surface | Source Boundary |
| --- | --- | --- | --- |
| identity fields | yes | Identity | Genesis-owned source truth. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size</code> | yes | Size & Spawn | Genesis-owned with DDD-derived read-only values. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">spawn</code> | yes | Size & Spawn | Default character spawn; level placement remains in Godot scenes. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">equipped_systems</code> | yes | Systems | Role-sensitive; validation blocks illegal combinations. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">character_template</code> | yes | Collision / Life & Hurtboxes | Character body and receive-side truth. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input</code> | yes | Input | Player/AI/none setup through the existing input/runtime contract; no extra actor-local node is added in baseline. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_loadout</code> | yes | Move Loadout | References canonical MoveData IDs. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set</code> | yes | SpriteSet Coverage | Visual coverage truth and rescan status. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">interaction</code> | conditional | Interaction | Only for interaction-capable roles. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis</code> | yes | Genesis Preferences | Scene preference / workflow data, not gameplay truth. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">validation</code> | yes | Validation | Generated/scanned report fields; read-only in normal editing. |

### <span style="color:#4F9D69"><u><strong>9.2 Baseline Records</strong></u></span>

| Character | JSON | Role | Faction | Systems | HP | DEF | Moves | Purpose |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">origin</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/origin.json</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">origin</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">neutral</code> | collision + visual | none | none | none | Smallest valid visible sprite. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">adam</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/adam.json</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">playable</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">player</code> | player combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">100</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch_3hit</code> | First controllable smoke target. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">eva</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/eva.json</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ally</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ally</code> | ally AI combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">100</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> | Follow/assist and ally-safe targeting. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">cain</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/cain.json</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">enemy</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">enemy</code> | enemy AI combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">100</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">2</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> | Hostile target and damage-formula smoke. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">solomen</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">genesis/defaults/solomen.json</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">neutral</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">neutral</code> | interaction | none | none | none | Dialogue/shop/trainer/quest baseline. |

## <span style="color:#2F80A8"><u><strong>10. Resource Rescan Contract</strong></u></span>

Genesis can rescan resources changed by Godot or external animation tools.

Baseline does not add a new resource path field. For v1, resource discovery uses project convention from existing fields:

```md
SpriteDefinition.id = adam
sprite_set.id = adam_spriteset
expected resource area = res://assets/characters/adam/
coverage owner = sprite_set.clip_coverage
```

Rescan may update or report:

| Item | Behavior |
| --- | --- |
| available clip names | Read-only evidence from Godot resource files. |
| frame counts | Read-only evidence. |
| missing coverage | Validation finding. |
| placeholder status | Visible <span style="color:#d97706"><strong>Generated/Scanned</strong></span> status in <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage.*.status</code>. |
| generated mirror status | Validation/generation report only. |

Genesis <strong><u><span style="color:#C65D5D">must not</span></u></strong> edit animation frames, sprite sheets, or Godot animation resources.

## <span style="color:#2F80A8"><u><strong>11. User Workflow</strong></u></span>

```md
Open Genesis
-> choose SpriteDefinition or clone baseline
-> edit fields in DetailEditor
-> optionally Rescan Bound Resources
-> open FloatingPreviewWindow if visual check is needed
-> validate schema + references + coverage + resolver
-> save JSON
-> place or run RuntimeActor.tscn with definition_path in Playground
-> optional Playground smoke
```

### <span style="color:#4F9D69"><u><strong>11.1 Save / Apply Rules</strong></u></span>

| Rule | Contract |
| --- | --- |
| Explicit apply | Field edits update a working draft, then save to JSON by user action. |
| No silent mutation | Validation cannot silently change source fields. It can propose fixes. |
| Round trip | Load -> save -> load must preserve source truth. |
| Rescan caution | Rescan may update scanned/coverage status only after user confirmation. |
| Generated assets | Regenerated from JSON and resource scan; never hand-edited as truth. |
| Invalid state | Invalid records remain visible and recoverable; blocking errors prevent export/smoke. |

## <span style="color:#2F80A8"><u><strong>12. Validation Contract</strong></u></span>

| Check | Scope | Blocking |
| --- | --- | --- |
| JSON parse | all SpriteDefinition files | yes |
| schema version | all SpriteDefinition files | yes |
| field coverage | DetailEditor covers every current SpriteDefinition path | yes |
| unique IDs | character library | yes |
| role/system compatibility | equipped systems and role | yes |
| collision rects | foot/body/hurtbox rects | yes |
| life contract | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hp_max</code> and LifeRuntime instancing | yes |
| MoveData references | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_loadout.equipped_moves</code> | yes |
| SpriteSet coverage | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_set.clip_coverage</code> | yes for required baseline clips |
| placeholder visibility | art and generated asset status | yes |
| runtime resolver parity | preview vs runtime resolver | yes |
| default baseline | five required records exist | yes |
| round trip | load/save/load | yes |
| old-name absence | no old authoring-scene name in current Genesis docs | yes |

## <span style="color:#2F80A8"><u><strong>13. Implementation Mapping</strong></u></span>

| Genesis Concept | Godot Mapping | Data Boundary |
| --- | --- | --- |
| GenesisRoot | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Control</code> scene | Scene shell only. |
| TopCommandBar | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">HBoxContainer</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Button</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">OptionButton</code> | Executes workflow commands. |
| DefinitionNavigator | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Tree</code> | View over JSON groups. |
| DetailEditor | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ScrollContainer</code> + schema-aware controls | Edits current draft fields. |
| ValidationDrawer | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">PanelContainer</code> / list | Shows validation report. |
| FloatingPreviewWindow | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Window</code> / popup <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Control</code> with <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SubViewport</code> | Preview only. |
| Save/Load | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">FileAccess</code> + JSON parser | Writes <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code>. |
| Rescan Bound Resources | Resource scan service/function | Reads Godot-owned assets; no animation editing. |
| RuntimeActor handoff | shared <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code> + <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">definition_path</code> | No per-character actor scene generation. |
| Playground smoke | headless or in-editor smoke entry | Uses saved JSON and runtime contracts. |

## <span style="color:#2F80A8"><u><strong>14. Design Consistency Checklist</strong></u></span>

- [x] Genesis naming is used consistently.
- [x] Old authoring-scene name is not used in this document.
- [x] Genesis uses one shared <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code>; no per-character generated actor scene baseline.
- [x] <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeActor.tscn</code> tree matches [[New PRD]] / [[ddd.md]].
- [x] DetailEditor field matrix covers current baseline JSON fields.
- [x] DetailEditor does not invent new SpriteDefinition fields.
- [x] Floating preview can be turned on/off and never becomes gameplay truth.
- [x] Godot-side plugin button is excluded from baseline.
- [x] Genesis/Godot interaction is file-based through <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">res://</code>.
- [x] Animation resource editing stays outside Genesis.
- [x] Validation reports schema, coverage, placeholder, resolver, and smoke readiness issues visibly.
- [x] Save/reload round trip preserves authored truth.
