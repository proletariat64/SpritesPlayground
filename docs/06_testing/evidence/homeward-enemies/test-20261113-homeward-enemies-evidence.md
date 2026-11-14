---
title: "Homeward generated enemy art evidence"
doc_type: test_evidence
status: active
owner: SpritesPlayground maintainers
source: user request
created: 2026-11-13
updated: 2026-11-13
---

# Homeward generated enemy art evidence

## Scope

Five genuinely new enemy identities now supply the Homeward enemy SpriteFrames. The original Miduo player resources, shared combat code, authored move data, timing, damage and waves were not edited for this integration. Only `homeward_actor.gd` changes an existing runtime presentation seam; the factory is stage-only and in-memory.

- `*_frames.png`: all 48 curated poses per identity; source idle is explicitly marked **not runtime**. Guard holds safe punch pose 0.
- `<school_gate|shopping_street|homeward_alley>_<guard|contact|fallen>_lineup.png`: nine **staged lineups**, not real-route screenshots. Every image includes original Miduo and all five new enemy identities, alternating enemy facings.
- `normal_ai_route.jsonl`: separate automated normal-AI route evidence, not human playtesting. Produced with the existing `/tmp/homeward_normal_uat.gd` InputEventKey driver; it asserts enemies remain live AI, first waits for defeat, retries via Enter, then fights through all four encounters and walks home. No dummy/enemy/stat mutation in that driver.

## Visual inspection

The headed lineup capture used its own temporary Godot process (final capture PID 294808), not the user's older process. It used no OS keyboard injection. The harness expands its staged lane and moves its camera for each background; its HUD still says encounter 1 because this is explicitly a lineup, not a claim of progression.

Inspected the school guard/contact/fallen images, shopping contact image and residential fallen image, plus captain and violet contact sheets. Feet sit on one floor, silhouettes remain visible against all three backgrounds, contacts face the intended direction, and fallen figures including the captain's repaired hand remain inside cells. No visible transparent-background specks or halo remain. Boss art still has somewhat finer detail than original Miduo; perfect pixel parity is not claimed.

Reproduce the staged capture in an isolated headed process:

```bash
env WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir \
  godot --path . --script tools/homeward_enemy_visual_proof.gd
```

## Focused checks

- `python3 -m unittest tests.test_homeward_enemy_art -v`: 3 tests pass. Covers exact deterministic rebuild bytes, 13 unchanged source PNGs, all 240 nonempty/unclipped binary-alpha poses, standing scale and floor, actual pose changes, expanded captain hand and removal of the foreign preceding-cell hand.
- Direct original comparison against `/tmp/miduo-gpt-assets-batch2/raw/`: all 13 copied originals byte-identical.
- `python3 -m py_compile tools/build_homeward_enemy_art.py tests/test_homeward_enemy_art.py`: pass.
- `godot --headless --path . --editor --import --quit`: exit 0, resources import and runtime smoke loads succeed. **Engine shutdown diagnostic remains:** `Condition "!thread.is_started()" is true` in `gdscript_language_server.cpp:111`. This is an editor language-server stop diagnostic, not a clean stderr claim; no config changes were made to hide it.
- `godot --headless --path . --script tools/homeward_enemy_art_smoke.gd`: pass. Five distinct runtime atlas resources; original player resource/pixels preserved; both facings; genuinely changing walk/run playback; fixed guard; attack textures tied to current executor frame, active contact and real damage; hurt/fall/down/get-up/death/reset.
- Existing `homeward_stage_smoke`, `homeward_input_smoke`, `input_event_controls_smoke`, `miduo_import_smoke`: pass.
- `godot --headless --fixed-fps 60 --path . --script /tmp/homeward_normal_uat.gd`: exit 0. Idle player defeated; defeat frozen; Enter retry reset state; live AI four-wave route victory, spawn counts `[1,1,1,1]`, 17 landed hits, 48.383 simulated route seconds. The automated controller finished with 100 HP; this is **not** proof of human difficulty balance.
- Changed Python LSP probe: no findings; one silent-on-clean recheck was inconclusive. Executable Python tests/compile checks are the concrete proof.
- `git diff --check`: pass.

## Reaction-clock review repair

Independent regression review found that three-frame enemy reactions ended before the inherited phase timers: the shared non-attack playback restarted them, showing repeated falling/getting up. The narrow repair only adds a Homeward actor presentation override: after inherited setup, enemy hurt/dead frames are paused and selected from authoritative `state_elapsed`, subtracting the inherited fall/down durations for get-up and clamping to the last pose. Player playback, attack executor frames, locomotion autoplay, state timings and art remain unchanged.

`godot --headless --path . --script tools/homeward_enemy_reaction_smoke.gd` failed **before** the production fix with phase-local rewinds/final-pose loss and paused-frame drift for all five roles; the unchanged test passes **after** the fix. It uses actual process-time waits between public `take_hit`/`stage_tick` calls, observes whole ordinary-hurt, knockdown and death phases, allows phase transitions/new-hit resets, checks final-pose holds, paused reactions and reset, and compares the player's playback with a shared-base peer. See `reaction_red.log` and `reaction_green.log`.

Focused `homeward_enemy_art_smoke`, `homeward_stage_smoke` and `homeward_input_smoke` also pass after the repair, preserving actual walk/run autoplay, attack-frame alignment, player pixels, stage flow and input behavior. No assets were regenerated and no shared base was edited. Earlier route/screenshot evidence above belongs to the pre-repair integration; this batch adds elapsed-time regression proof, not a new human-playtest claim.

## Review boundaries

Graph search/callers/impact and final update/detect-changes against `main` ran. The graph still excludes untracked Homeward code; it reports only four tracked changed files and zero affected indexed symbols. **That zero is not evidence of no impact.** Actual manual flow: `Stage.spawn_actor` -> actor `_ready` -> in-memory frames; shared `_sync_visual_animation` -> stage-only virtual resolver. Direct affected presentation flow is Homeward enemies only. Player and Playground retain original resolver/resources. No HIGH/CRITICAL graph warning was returned.

Attack timing discovery: authored jab/cross contact is executor 1..2, but new sheet contact poses are source 2..3. Presentation maps punch clock indices `[0,1,2,3,4,5]` to source `[0,2,3,4,5,5]`; kick is direct 0..5. This compresses punch anticipation without moving hitbox events. Roundhouse/heavy kicks reuse actual generated kick poses, rush uses punch poses and existing velocity events; unique boss special sheets and enemy jump art were not generated.

No paid/provider calls, retries, authentication/config edits, staging or commits were performed. Existing user `.pi/settings.json` and `scripts/candidate_fingerprint.sh` modifications were preserved. No final Makefile certification gates were run by the implementer.
