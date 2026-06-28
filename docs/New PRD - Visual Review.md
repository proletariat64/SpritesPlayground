---
title: SpritesPlayground Clean PRD
status: current-clean
updated: 2026-06-28
tags:
  - prd
  - spritesplayground
  - godot
  - act
---

# <span style="color:#6D5BD0"><u><strong>SpritesPlayground Clean PRD</strong></u></span>

<small><em>Genesis 1:3 — Let there be light; then make it playable.</em></small><br>
<small><em>Genesis 1:31 — Good enough to ship, not large enough to worship.</em></small>

## <span style="color:#2F80A8"><u><strong>1. Product Thesis</strong></u></span>

<small><em>Genesis 1:1 — Start with a world, not an engine.</em></small><br>
<small><em>Genesis 2:15 — Dress it, keep it, play in it.</em></small>

SpritesPlayground is a constrained 2D pixel ACT playground for making classic belt-scroll arcade games with swappable family-character skins, strong game feel, and fast level/play experimentation.

It is not a general 2D engine. The product deliberately trades breadth for repeatable production speed, readable pixel art, and tight action feel.

| Product Goal | Contract |
| --- | --- |
| Game quality target | Match the feel clarity of classic arcade belt-scroll action. |
| Content target | Put the user, family, and custom characters into playable scenes. |
| Production target | Re-skin characters quickly without redesigning systems. |
| Feel target | Responsive input, command buffer, <strong><span style="color:#D48A33">cancel windows</span></strong>, <strong><span style="color:#C65D5D">hitstop</span></strong>, hitstun, and combo timing. |
| Architecture target | Use Godot and existing modules first; write thin glue, not a new engine. |

## <span style="color:#2F80A8"><u><strong>2. References</strong></u></span>

<small><em>Genesis 2:19 — Name the creatures before expanding the rules.</em></small><br>
<small><em>Proverbs 22:28 — Do not move old landmarks without reason.</em></small>

| Ref | Source | Applied Constraint |
| --- | --- | --- |
| R1 | [Captain Commando move list](https://gamefaqs.gamespot.com/arcade/583851-captain-commando/faqs/54091), [TMNT: Turtles in Time controls](https://gamefaqs.gamespot.com/arcade/575653-teenage-mutant-ninja-turtles-turtles-in-time/faqs/13142), [River City Ransom controls](https://gamefaqs.gamespot.com/nes/563453-river-city-ransom/faqs/3081), [Warriors of Fate move list](https://gamefaqs.gamespot.com/arcade/564356-warriors-of-fate/faqs/71365) | Classic belt-scroll baseline: broad ground movement, side-facing attacks, forward jump attacks, simple command feel, and specials driven by timing rather than full attack-direction animation sets. |
| R2 | [[PRD_CURRENT_CLEAN]] | Internal data boundary: CharacterTemplate owns body/status; MoveData owns timing/hit logic; SpriteSet owns visual coverage. |
| R3 | [Godot 4.6 docs](https://docs.godotengine.org/en/4.6/) | Use built-ins first: CharacterBody2D, Area2D, AnimationPlayer, AnimatedSprite2D, ProgressBar/Control, Tree, SplitContainer, CanvasItem y-sort/z-index, JSON/FileAccess. |
| R4 | [LimboAI docs](https://limboai.readthedocs.io/en/stable/) | Use LimboHSM, BTState, BehaviorTree, Blackboard, and debugger for state/behavior orchestration. |
| R5 | [Fray](https://github.com/Pyxus/fray), [godot-health-hitbox-hurtbox](https://github.com/cluttered-code/godot-health-hitbox-hurtbox) | Research/reference only: study Fray input code; spike cluttered-code hit/hurt/health only if it does not fight our data model. |

## <span style="color:#2F80A8"><u><strong>3. Design Decisions</strong></u></span>

<small><em>Genesis 1:4 — Separate signal from noise.</em></small><br>
<small><em>Genesis 1:6 — A firmament is a boundary, not a feature request.</em></small>

| Decision | Rule |
| --- | --- |
| Not an engine | No general-purpose state graph, animation graph, combat framework, or asset editor. |
| Direction is action coverage | Direction never creates State branches. Each action declares its own visual coverage policy. |
| Movement earns direction cost | Only walk/run require full travel coverage by default. |
| Combat earns feel cost | Attacks invest in startup, active frames, recovery, input buffer, <strong><span style="color:#D48A33">cancel windows</span></strong>, <strong><span style="color:#C65D5D">hitstop</span></strong>, hitstun, SFX/VFX, and enemy reaction. They do not earn south/north variants by default. |
| 12 fps is visual, not latency | Pixel animation uses 12 authored fps; input/combat resolution targets 60 Hz. |
| Mirror is production output | Mirrored clips and mirrored hitboxes are materialized by preprocessing. Runtime plays resolved assets; it does not do production mirroring. |
| South/north are bespoke | Horizontal mirror only covers east/west pairs. South and north are never generated from each other. |
| Data owns behavior | MoveData, CharacterTemplate, SpriteSet, and runtime Blackboard have explicit ownership. Animation names do not define gameplay. |
| Frame is timeline | Authored frames are the shared timeline for animation beats, hitboxes, hurtboxes, SFX/VFX triggers, <strong><span style="color:#D48A33">cancel windows</span></strong>, and recovery. Runtime ticks resolve against this frame timeline instead of inventing separate timing rules. |
| Component equipment | A sprite gains abilities by freely composing layered equipment/system components, and each added component also binds the sprite to that system's rules and constraints. |
| Current truth | Only [[New PRD]] and [[ddd]] are current design truth. Historical PRDs, v0.3 data, and existing runtime code are reference/migration evidence, not authoritative contracts. |
| Combat damage truth | Damage is always <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">max(0, hitbox_atk - selected_hurtbox_def)</code>. Hurtbox DEF defaults to <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code>; direct <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">damage</code> fields are not gameplay truth. |
| Segment combo, not command tree | Baseline combo-hit moves are linear segmented MoveData. Same-prefix dynamic branches such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code> vs <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAB</code> are out of baseline. |

## <span style="color:#2F80A8"><u><strong>4. World Contract</strong></u></span>

<small><em>Genesis 1:14 — Signs, seasons, days, and measures.</em></small><br>
<small><em>Genesis 1:16 — Two lights: one for play, one for presentation.</em></small>

| Input Item | Value | Contract |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">game_style</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">2D pixel ACT side-scroll arcade</code> | Belt-scroll arcade action with 2D gameplay collision. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">logical_resolution</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">640x360</code> | Gameplay coordinate base. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">screen_resolution</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1280x720</code> | Default presentation resolution. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">logical_pixel_size</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">2x2</code> | 1 logical pixel maps to 2x2 screen pixels. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">texture_filter</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">nearest</code> | Blurred pixel filtering is <strong><u><span style="color:#C65D5D">forbidden</span></u></strong>. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">sprite_palette</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Lospec EDG64</code> | Default sprite palette. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">scene_palette</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">unrestricted</code> | Background palette is free but must preserve sprite readability. |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">authoring_fps</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">12</code> | Animation beats and move timing tables use authored frames. |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">runtime_tick_rate</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">60</code> | Input polling, command parsing, hit checks, <strong><span style="color:#C65D5D">hitstop</span></strong>, <strong><span style="color:#D48A33">cancel windows</span></strong>, and combat resolution target 60 Hz. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">frame_unit</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">1 authored frame = 1 beat</code> | One design frame maps to multiple runtime ticks. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">edit_animation</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">false</code> | Crop, slicing, palette work, and paint edits happen in external art tools. |

## <span style="color:#2F80A8"><u><strong>5. Direction Contract</strong></u></span>

<small><em>Genesis 13:11 — East has meaning; do not mirror the whole world.</em></small><br>
<small><em>Genesis 28:14 — North, south, east, west; each has its place.</em></small>

### <span style="color:#4F9D69"><u><strong>5.1 Vocabulary</strong></u></span>

| Item | Contract |
| --- | --- |
| Logical facings | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south_west</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">west</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north_west</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north_east</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">east</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south_east</code> |
| Mirror pairs | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">east↔west</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south_east↔south_west</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north_east↔north_west</code> |
| Bespoke facings | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north</code> |
| Forbidden mirror | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south↔north</code> |

### <span style="color:#4F9D69"><u><strong>5.2 Direction Policies</strong></u></span>

| Policy | Required authored facings | Generated facings | Use |
| --- | --- | --- | --- |
| <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code> | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south</code> | none | idle, dead, simple presentation clips |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">east</code> | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">west</code> | dash, jump, attack, jump_attack, hurt, block, parry |
| <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code> | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">east</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south_east</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north_east</code> | <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">west</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">south_west</code>, <code style="color:#667085;font-weight:600;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">north_west</code> | walk, run |
| <code style="color:#7C65C1;font-weight:700;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">custom</code> | move-defined | move-defined | bosses, gimmicks, special moves only |

### <span style="color:#4F9D69"><u><strong>5.3 Baseline Action Coverage</strong></u></span>

| Action | Policy | Minimum Clip | Constraint |
| --- | --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle</code> | <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code> | south idle | Face camera. No side idle required. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> | <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code> | south dead | Same presentation rule as idle. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">walk</code> | <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code> | travel walk set | Movement uses full travel coverage. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">run</code> | <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code> | travel run set | Same coverage as walk. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dash</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | east dash | Side burst only. Combat dash does not add north/south variants. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | east jump | Vertical action with left/right facing. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | east attack | No south/north baseline attacks. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump_attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | east jump_attack | No south/north baseline jump attacks. Special cases use <code style="color:#7C65C1;font-weight:700;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">custom</code>. |
| <code style="color:#C65D5D;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">360_attack</code> | move-defined visual | one readable clip | Area coverage comes from timed hitboxes, not eight directional clips. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurt</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | east hurt | Hit source controls reaction direction. |

## <span style="color:#2F80A8"><u><strong>6. Timing & Feel Contract</strong></u></span>

<small><em>Genesis 1:5 — Evening and morning: the first beat.</em></small><br>
<small><em>Ecclesiastes 3:1 — Every action has its window.</em></small>

| Layer | Rate | Rule |
| --- | --- | --- |
| Visual animation | 12 authored fps | Pixel animation stays sparse and readable. |
| Input polling | 60 Hz | Press/release edges <strong><u><span style="color:#C65D5D">must not</span></u></strong> be quantized to 12 fps. |
| <strong><span style="color:#2F80A8">Input buffer</span></strong> | 60 Hz | Command pre-input and leniency windows are runtime-tick precise. |
| Move gates | authored frames | Startup, active, recovery, cancel, <strong><span style="color:#C65D5D">hitstop</span></strong>, and hitstun are authored in frames. |
| Combat resolution | 60 Hz with authored-frame gates | Hit checks and cancel eligibility evaluate at runtime tick precision. |
| Rendering | 60 fps target | Rendering performance is not a design limiter for this scope. |

Required feel systems:

| System | Purpose | Scope |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input_buffer</code> | Accept early commands before a legal window opens. | Required for responsive action. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">command_parser</code> | Recognize simple command motions or button sequences. | Use existing modules where possible. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">cancel_window</code> | Allow controlled chains and combo routes. | MoveData-owned. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hitstop</code> | Store impact-freeze timing for weight and readability. | MoveData / hitbox profile default; first slice may smoke-record before full visual freeze. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hitstun</code> | Store target reaction timing metadata. | Placeholder for first runtime slice; not a required stun-lock system yet. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">combo_string</code> | Resolve linear continuation strings such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code> into one segmented MoveData execution. | Driven by input buffer and segment gates; hit-count display is derived feedback, not combo logic. |

## <span style="color:#2F80A8"><u><strong>7. Data Ownership</strong></u></span>

<small><em>Genesis 2:19 — What is named can be owned.</em></small><br>
<small><em>Numbers 34:2 — Boundaries keep the land sane.</em></small>

| Data | Owner | Persistent | Owns | Does Not Own |
| --- | --- | --- | --- | --- |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CharacterTemplate</code> | character/template data | yes | size class, base hurtboxes, hurtbox DEF, foot/body collision, HP baseline, equipped moves, SpriteSet ref | move timing, hitbox ATK, animation frames |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">MoveData</code> | action behavior data | yes | category, state_event, direction_policy, segments, segment input gates, startup/active/recovery, hitbox ATK profiles, cancel rules, input command, finish event | sprite frame files, permanent character body, target HP |
| <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteSet</code> | visual coverage data | yes | action clips, direction coverage, authored/generated/missing status, frame sequences, generated mirror provenance | damage math, hit logic, HP |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeBlackboard</code> | runtime instance data | no | current state, current move, facing, velocity, HP runtime, input buffer state, hurt result | source-of-truth authored data |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">GeneratedSpriteFrames</code> | preprocessed runtime visual resource | rebuildable | resolved animations, materialized mirrored clips | authoring truth |

## <span style="color:#2F80A8"><u><strong>8. Sprite Entity Tiers</strong></u></span>

<small><em>Genesis 2:7 — Dust first; breath later.</em></small><br>
<small><em>Genesis 5:2 — Call their name Adam, and keep the joke alive.</em></small>

| Tier | Name | Definition | Allowed Systems |
| --- | --- | --- | --- |
| No.0 | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">origin / OriginSprite</code> | Smallest valid visible sprite. It proves render, size, idle, collision/debug, and validation. | CollisionBody, VisualPresenter, Size validation, idle State only. |
| No.1 | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Adam</code> | First controllable combat sprite; the origin with breath, input, hurt, HP, hitboxes, and move execution. | StateDriver, InputSystem, MoveRuntime, CombatPorts, LifeRuntime, VisualPresenter. |
| No.2 | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Eva</code> | Friendly AI partner that helps Adam fight; validates follow/assist behavior, target sharing, and ally-safe hit rules. | StateDriver, AI behavior, faction/targeting adapter, MoveRuntime, CombatPorts, LifeRuntime, VisualPresenter. |
| No.3 | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Cain</code> | Hostile combat NPC; Cain is the first enemy test case for hostile targeting, approach, hurt reaction, and attack-string response. | StateDriver, AI behavior, targeting adapter, MoveRuntime, CombatPorts, LifeRuntime, VisualPresenter. |
| No.4 | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Solomen</code> | Non-combat interaction role; Solomen is the first neutral test case for story dialogue, shops, trainers that teach equipment skills, and quest providers. | Interaction adapter, dialogue/shop/trainer/quest data; combat systems optional. |
| Runtime Cast | family/custom sprites | Re-skinned playable/ally/enemy/neutral characters using the same template and SpriteSet contracts. | Systems are equipped by role; no role receives combat, dialogue, shop, trainer, or quest behavior implicitly. |

No.0 is not a parent class. It is the origin composition reused by Adam, Eva, Cain, Solomen.

## <span style="color:#2F80A8"><u><strong>9. Overall Architecture Contract</strong></u></span>

<small><em>Exodus 18:25 — Appoint rulers of thousands, hundreds, fifties, tens.</em></small><br>
<small><em>Genesis 41:40 — Let one steward order the house.</em></small>

Use Godot primitives and LimboAI orchestration. Build only thin ACT-specific runtime components. Do not build a general engine.

### <span style="color:#4F9D69"><u><strong>9.1 Module Map</strong></u></span>

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">SpritesPlayground</span>
<span style="color:#2F80A8;font-weight:700">|-- Authoring Data</span>
<span style="color:#4F9D69;font-weight:500">|   |-- CharacterTemplate</span>
<span style="color:#4F9D69;font-weight:500">|   |-- MoveData</span>
<span style="color:#4F9D69;font-weight:500">|   |-- SpriteSet</span>
<span style="color:#4F9D69;font-weight:500">|   `-- GeneratedSpriteFrames</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- Actor Runtime</span>
<span style="color:#4F9D69;font-weight:500">|   |-- StateDriver</span>
<span style="color:#4F9D69;font-weight:500">|   |-- InputSystem</span>
<span style="color:#4F9D69;font-weight:500">|   |-- MoveRuntime</span>
<span style="color:#4F9D69;font-weight:500">|   |-- CombatPorts</span>
<span style="color:#4F9D69;font-weight:500">|   |-- LifeRuntime</span>
<span style="color:#4F9D69;font-weight:500">|   `-- VisualPresenter</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">|-- Stage Runtime</span>
<span style="color:#4F9D69;font-weight:500">|   |-- CombatResolver</span>
<span style="color:#4F9D69;font-weight:500">|   |-- DepthSortSystem</span>
<span style="color:#4F9D69;font-weight:500">|   `-- SpawnResetSystem</span>
<span style="color:#5B677A;font-weight:700">|</span>
<span style="color:#2F80A8;font-weight:700">`-- Genesis</span>
<span style="color:#4F9D69;font-weight:500">    |-- DefinitionNavigator</span>
<span style="color:#4F9D69;font-weight:500">    |-- DetailEditor</span>
<span style="color:#4F9D69;font-weight:500">    |-- FloatingPreviewWindow</span>
<span style="color:#4F9D69;font-weight:500">    `-- ValidationDrawer</span>
</pre>

### <span style="color:#4F9D69"><u><strong>9.2 Build / Reuse Decision</strong></u></span>

| Need | Decision | Reason |
| --- | --- | --- |
| movement body | Godot <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CharacterBody2D</code> | Native script-driven character movement. |
| hit/hurt shapes | Godot <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Area2D</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CollisionShape2D</code> | Native overlap primitives; our data drives shape timing. |
| animation playback | <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AnimatedSprite2D</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteFrames</code> / <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AnimationPlayer</code> | Native playback plus exact frame/event gates. |
| state / behavior orchestration | LimboAI <code style="color:#7C65C1;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">LimboHSM</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">BTState</code>, <code style="color:#7C65C1;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">BehaviorTree</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Blackboard</code> | Existing addon with debugger; no custom state framework. |
| input buffer / command sequence | Study/vendor Fray GDScript input code where useful | Copy only the small input part; do not adopt Fray as full combat architecture. |
| hit/hurt/health plugin | Optional spike: <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">cluttered-code/godot-health-hitbox-hurtbox</code> | Reference or borrow if it does not bypass our CombatResolver and HurtResult flow. |
| damage resolver | Own thin <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CombatResolver</code> | Damage is game rule, not a library concern. |
| HP / death | Own thin <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">LifeRuntime</code> | HP is trivial; keep it readable. |
| visual adapter | Own <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">VisualPresenter</code> | SpriteSet, direction policy, generated mirrors, fallback, and frame sync are project-specific. |
| UI shell | Godot <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Tree</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SplitContainer</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Control</code> | Native editor-like UI; no custom UI framework. |
| persistence | JSON + schema validation | Diffable, external-tool friendly, Genesis friendly. |

### <span style="color:#4F9D69"><u><strong>9.3 System Count Rule</strong></u></span>

Do not promote every concept into a node.

| Keep As System | Keep As Internal Function / Data |
| --- | --- |
| independent lifecycle, reset, signals, debug surface, or cross-actor relation | formula, display mode, one-off adapter, scalar config, derived flag |

Baseline is six actor-local components and three stage services. Anything beyond that must earn its node.

## <span style="color:#2F80A8"><u><strong>10. Adam Runtime Tree</strong></u></span>

<small><em>Genesis 2:7 — Form first; breath second.</em></small><br>
<small><em>Genesis 5:2 — Adam is the first contract, not the whole tribe.</em></small>

Adam is the first full playable runtime composition.

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">Adam : CharacterBody2D</span>
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

Stage-level services are not children of Adam:

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">StageRuntime</span>
<span style="color:#2F80A8;font-weight:700">|-- CombatResolver</span>
<span style="color:#2F80A8;font-weight:700">|-- DepthSortSystem</span>
<span style="color:#2F80A8;font-weight:700">`-- SpawnResetSystem</span>
</pre>

### <span style="color:#4F9D69"><u><strong>10.1 Actor Component Boundaries</strong></u></span>

| Component | Owns | Must Not Own |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">StateDriver</code> | active state, legal transitions, BTState execution, Blackboard handoff | raw input, damage formula, animation asset ownership |
| <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">InputSystem</code> | Godot input read, pre-input buffer, combo string, command sequence, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">input_intent</code> | state transition authority, damage, visual playback |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">MoveRuntime</code> | current MoveData, authored frame index, startup/active/recovery, <strong><span style="color:#D48A33">cancel windows</span></strong>, <strong><span style="color:#C65D5D">hitstop</span></strong> gate, frame events | target traversal, HP, SpriteSet ownership |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CombatPorts.HitboxSource</code> | active hitbox samples for the current move frame | target search, final damage, HP mutation |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CombatPorts.HurtboxReceiver</code> | hurtbox samples, DEF, invincible/armor/guard effective flags, hurt reaction result | final damage formula, HP mutation, rendering |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">LifeRuntime</code> | max HP, current HP, apply final damage, death event | ATK, DEF, invincibility, armor, health bar rendering |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">VisualPresenter</code> | SpriteSet clip resolution, SpriteFrames playback, frame sync, health bars, hit flash, debug overlay | combat truth, HP truth, state authority |

### <span style="color:#4F9D69"><u><strong>10.2 Stage Service Boundaries</strong></u></span>

| Service | Owns | Reason |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CombatResolver</code> | attacker-target traversal, hitbox-hurtbox intersection, hit-once registry, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">max(0, hitbox_atk - hurtbox_def)</code>, HurtResult dispatch | Damage is a world relation between two actors. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">DepthSortSystem</code> | foot-Y sort, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">z_index</code> write, depth debug | Render order is actor-relative, not actor-local. |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpawnResetSystem</code> | spawn points, template binding, reset-to-template, Playground UAT lifecycle | Creation/reset is stage lifecycle, not combat behavior. |

## <span style="color:#2F80A8"><u><strong>11. Behavior-Driven Runtime Model</strong></u></span>

<small><em>Genesis 1:4 — Separate signal from noise.</em></small><br>
<small><em>Ecclesiastes 3:1 — Every action has its window.</em></small>

Sprites are driven by events, state context, and MoveData execution. Animation names never drive gameplay.

```md
CharacterTemplate + SpriteSet + equipped systems
-> Runtime Actor Instance
-> RuntimeBlackboard initialized
-> StateDriver enters initial state
-> InputSystem / AI / CombatResolver emits event
-> StateDriver activates target BTState
-> BTState selects Non-Move behavior or MoveData
-> MoveRuntime / VisualPresenter / CombatPorts execute the frame
-> CombatResolver resolves cross-actor hits
-> ev_finished / ev_hurt / ev_dead drives the next state
```

### <span style="color:#4F9D69"><u><strong>11.1 Runtime Instancing</strong></u></span>

```md
CharacterTemplate
-> body size, HP baseline, base hurtboxes, hurtbox DEF, foot collision, equipped move refs
SpriteSet
-> visual coverage, direction policy support, generated SpriteFrames refs
Role / equipped systems
-> input, AI, faction, interaction, combat, trainer, shop, quest capability
```

Runtime-only defaults:

```md
RuntimeBlackboard.current_state = idle
RuntimeBlackboard.current_move = null
RuntimeBlackboard.facing_dir = spawn-defined or south
RuntimeBlackboard.velocity = Vector2.ZERO
RuntimeBlackboard.hp = CharacterTemplate.hp
RuntimeBlackboard.input_buffer = empty
RuntimeBlackboard.hurt_result = null
```

The initial expression is <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle</code> State plus resolved idle clip. It is not an <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle MoveData</code>.

### <span style="color:#4F9D69"><u><strong>11.2 Driver Chains</strong></u></span>

| Chain | Used For | Examples | Driver |
| --- | --- | --- | --- |
| Non-Move | continuous control, passive reaction, terminal state, presentation-only behavior | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">walk</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">fall</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurt</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> | StateDriver + VisualPresenter + physics/reaction rules |
| MoveData | committed actions with authored timing windows, input command, cancel rules, hitboxes, or skill result | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code>, committed <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dash</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">parry</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">special</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump_attack</code> | MoveRuntime + CombatPorts + VisualPresenter |

Rules:

- <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">category</code> classifies selected MoveData. It does not decide whether behavior is a move.
- If behavior has startup / active / recovery / <strong><span style="color:#D48A33">cancel windows</span></strong>, it is MoveData.
- Dash is MoveData only when committed with authored timing, invulnerability, cost, cancel, or combat result.

## <span style="color:#2F80A8"><u><strong>12. State Contract</strong></u></span>

<small><em>Genesis 8:22 — Seedtime and harvest; state has seasons.</em></small><br>
<small><em>Genesis 1:4 — Do not mix light and darkness in one enum.</em></small>

State describes control/physics context only. It does not encode direction, animation variant, skin, combo branch, attack type, or damage.

| State | Purpose | Default Driver |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle</code> | neutral / wait / return target | Non-Move behavior + idle visual clip |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">walk</code> | grounded travel movement | Non-Move behavior + velocity update |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump</code> | takeoff / rising action | Non-Move behavior unless MoveData overrides it |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">fall</code> | airborne falling action | Non-Move behavior |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">attack</code> | executing committed MoveData | MoveRuntime |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurt</code> | receiving hit reaction | HurtResult-driven Non-Move reaction |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> | defeated state | Non-Move terminal behavior |

Baseline events:

```md
ev_move
ev_stop
ev_jump
ev_fall
ev_land
ev_attack
ev_hurt
ev_dead
ev_finished
```

Transition intent:

```md
idle   --ev_move-->     walk
walk   --ev_stop-->     idle
idle   --ev_jump-->     jump
walk   --ev_jump-->     jump
jump   --ev_fall-->     fall
fall   --ev_land-->     idle / walk
idle   --ev_attack-->   attack
walk   --ev_attack-->   attack
attack --ev_finished--> idle / walk
any    --ev_hurt-->     hurt
hurt   --ev_finished--> idle / walk
any    --ev_dead-->     dead
```

Dash is a MoveData behavior, not a required baseline State.

## <span style="color:#2F80A8"><u><strong>13. Input and Move Runtime Contract</strong></u></span>

<small><em>Genesis 4:7 — Action waits at the door.</em></small><br>
<small><em>Exodus 31:3 — Skill, craft, and timing belong to the work.</em></small>

### <span style="color:#4F9D69"><u><strong>13.1 InputSystem</strong></u></span>

InputSystem is the actor-local input adapter. It produces intent; it does not own transitions.

| Layer | Contract |
| --- | --- |
| raw input | Read Godot <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">Input</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">InputMap</code> actions such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">D</code> and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">J</code>. |
| input action | Map physical input to symbolic action, e.g. <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">D -&gt; move_right</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">J -&gt; attack_light</code>. |
| pre-input buffer | Store recent press/release edges for leniency and segment continuation. |
| input intent | Convert buffered input into intent such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">move_axis</code> or <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">attack_light</code>. |
| combo string | Resolve linear strings such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">JJJ</code> as continuation gates inside one segmented MoveData. |
| command sequence | Support small command motions / 搓招 after Fray input code study; branchy same-prefix command trees are out of baseline. |
| output | Emit coarse StateEvent such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> to StateDriver, and MoveCommand such as <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">advance_segment</code> to MoveRuntime when already attacking. |

### <span style="color:#4F9D69"><u><strong>13.2 MoveRuntime</strong></u></span>

A move is a committed action data contract executed after StateDriver enters a committed context. A move is not a node tree and not a general behavior label.

A MoveData may be single-segment or segmented:

| Shape | Example | Rule |
| --- | --- | --- |
| single-segment MoveData | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> | One input intent starts one segment, then finishes. |
| segmented MoveData | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch_3hit</code> | One committed move contains ordered segments. Later inputs only decide whether the next segment plays. |

Input is layered:

```md
raw key J
-> input action attack_light
-> input intent attack_light
-> StateEvent ev_attack only when entering attack context
-> MoveCommand start_move / advance_segment inside MoveRuntime
```

Rules:

| Rule | Contract |
| --- | --- |
| timing | Startup, active, recovery, cancel, <strong><span style="color:#C65D5D">hitstop</span></strong>, and hitstun metadata are authored in frames. |
| execution | MoveRuntime reads MoveData; StateDriver owns only the coarse state transition. |
| state event | StateDriver sees <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code>; it <strong><u><span style="color:#C65D5D">must not</span></u></strong> require <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_AAA</code> or per-segment state events. |
| segment gates | Subsequent <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">J</code> presses during a segment gate may advance the current MoveData to the next segment. |
| branch limit | Baseline supports linear continuation only. <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">BBB</code>, and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">CBBB</code> may be separate first-token-disjoint moves; <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code> vs <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAB</code> sharing the same prefix is out of baseline. |
| complete recovery | If the next input arrives after the move fully finishes, it starts a new move instance rather than continuing the old segmented move. |
| exit | MoveData ends through <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">finish_event</code> unless interrupted by hurt/dead rules. |
| <strong><span style="color:#C65D5D">hitstop</span></strong> / hitstun | Values are persisted and reported. Hitstun is placeholder-only until a dedicated stun-lock slice exists. |

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">MoveData</span>
<span style="color:#2F80A8;font-weight:700">|-- id</span>
<span style="color:#2F80A8;font-weight:700">|-- category</span>
<span style="color:#2F80A8;font-weight:700">|-- state_event</span>
<span style="color:#2F80A8;font-weight:700">|-- direction_policy</span>
<span style="color:#2F80A8;font-weight:700">|-- animation_name</span>
<span style="color:#2F80A8;font-weight:700">|-- input_command</span>
<span style="color:#2F80A8;font-weight:700">|-- segments</span>
<span style="color:#4F9D69;font-weight:500">|   |-- segment_id</span>
<span style="color:#4F9D69;font-weight:500">|   |-- required_input</span>
<span style="color:#4F9D69;font-weight:500">|   |-- startup_frames</span>
<span style="color:#4F9D69;font-weight:500">|   |-- active_frames</span>
<span style="color:#4F9D69;font-weight:500">|   |-- recovery_frames</span>
<span style="color:#4F9D69;font-weight:500">|   |-- continuation_gate</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- input</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- open_frame</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- close_frame</span>
<span style="color:#D48A33;font-weight:500">|   |   `-- next_segment</span>
<span style="color:#4F9D69;font-weight:500">|   |-- hitbox_profiles</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- hitbox_id</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- atk</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- rect</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- active_window</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- hitstop_frames</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- hitstun_frames</span>
<span style="color:#D48A33;font-weight:500">|   |   |-- knockback</span>
<span style="color:#D48A33;font-weight:500">|   |   `-- reaction_tag</span>
<span style="color:#4F9D69;font-weight:500">|   `-- segment_attack_instance_id_policy</span>
<span style="color:#2F80A8;font-weight:700">`-- finish_event</span>
</pre>

<code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> is the official baseline punch <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">MoveData.id</code>. The three-hit variant is the explicit segmented MoveData <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch_3hit</code>.

## <span style="color:#2F80A8"><u><strong>14. Combat Contract</strong></u></span>

<small><em>Genesis 3:15 — Bruise the heel; count the hit.</em></small><br>
<small><em>Exodus 21:24 — Eye for eye, but only once per window.</em></small>

Combat is small and explicit. <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">atk</code> lives on hitboxes. <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">def</code>, invincible frames, armor, guard, and reaction rules live on effective hurtboxes. HP lives in LifeRuntime. Direct <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">damage</code> is not authoritative gameplay data.

### <span style="color:#4F9D69"><u><strong>14.1 Hitbox / Hurtbox Ownership</strong></u></span>

| Shape / Value | Owner | Purpose |
| --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hitbox_id</code> | MoveData / HitboxSource | attack sample identity |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hitbox_atk</code> | MoveData / HitboxSource | per-hitbox attack value |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hitbox_rect</code> | MoveData / HitboxSource | active attack area |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurtbox_id</code> | CharacterTemplate / HurtboxReceiver | receive area identity |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurtbox_def</code> | CharacterTemplate / HurtboxReceiver | per-hurtbox defense value; defaults to <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code> when omitted |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">invincible / armor / guard</code> | effective HurtboxReceiver state | hit accept rules; may come from current state or move modifiers |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">foot_collision</code> | CharacterTemplate / CollisionBody | occupancy, spacing, triggers, depth anchor |

Rules:

- Hitboxes are move-owned and exposed by <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">HitboxSource</code>.
- Hurtboxes are character-owned and exposed by <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">HurtboxReceiver</code>.
- Foot collision is not attack or hurt detection.
- Mirrored attacks use preprocessed mirrored hitbox profiles.
- South/north hitboxes require bespoke profiles when used.

### <span style="color:#4F9D69"><u><strong>14.2 Hit Resolution</strong></u></span>

```md
HitboxSource.active_samples
-> CombatResolver target traversal
-> HurtboxReceiver.effective_hurtboxes
-> intersect hitbox_rect with hurtbox_rect
-> reject if invincible / invalid target / already hit
-> selected_hurtbox_def = hurtbox_def or 0
-> final_damage = max(0, hitbox_atk - selected_hurtbox_def)
-> LifeRuntime.apply_damage(final_damage)
-> HurtboxReceiver builds HurtResult
-> RuntimeBlackboard.hurt_result = HurtResult
-> LifeRuntime emits observable ev_dead if HP <= 0
-> StateDriver dispatches ev_hurt or consumes ev_dead
-> VisualPresenter plays hit feedback
```

Rules:

- Damage formula is fixed: <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">max(0, hitbox_atk - selected_hurtbox_def)</code>.
- If a hurtbox has no configured DEF, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">selected_hurtbox_def = 0</code>.
- Direct <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">damage</code> fields are <strong><u><span style="color:#C65D5D">forbidden</span></u></strong> as runtime truth; they may exist only in migration reports as derived values.
- Each hitbox is calculated independently.
- One <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">attack_instance_id + hitbox_id + target_id</code> hits once unless <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">multi_hit = true</code>.
- A segmented MoveData creates a new <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">segment_attack_instance_id</code> per hit segment; <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">AAA</code> does not require <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">multi_hit = true</code>.
- Same-frame multi-hurtbox hits resolve by priority, then smallest area, then registration order.
- <code style="color:#C65D5D;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">360_attack</code> is one MoveData with timed multi-hitbox coverage; it does not require eight directional clips.
- Defense modifies damage only; StateDriver owns state changes.

### <span style="color:#4F9D69"><u><strong>14.3 LifeRuntime</strong></u></span>

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">LifeRuntime</span>
<span style="color:#2F80A8;font-weight:700">|-- max_hp</span>
<span style="color:#2F80A8;font-weight:700">|-- current_hp</span>
<span style="color:#2F80A8;font-weight:700">|-- apply_damage(final_damage)</span>
<span style="color:#2F80A8;font-weight:700">`-- death_event</span>
</pre>

Rules:

- LifeRuntime does not own ATK, DEF, invincibility, armor, <strong><span style="color:#C65D5D">hitstop</span></strong>, hurt animation, or health bar rendering.
- LifeRuntime receives final damage only.
- Death requires <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">current_hp &lt;= 0</code>.
- LifeRuntime must emit an observable <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code>.
- StateDriver must consume <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code> and enter <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> state.
- Smoke acceptance requires both <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code> emission and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">RuntimeBlackboard.current_state = dead</code>.

## <span style="color:#2F80A8"><u><strong>15. SpriteSet and Visual Presenter Contract</strong></u></span>

<small><em>Genesis 2:19 — Every living frame needs a name.</em></small><br>
<small><em>Exodus 35:35 — Engraver, designer, and weaver stay in their lane.</em></small>

SpriteSet is the visual coverage owner. VisualPresenter is the runtime adapter.

### <span style="color:#4F9D69"><u><strong>15.1 SpriteSet Responsibilities</strong></u></span>

| Responsibility | Contract |
| --- | --- |
| action coverage | Declare which actions and directions exist. |
| slot status | Track authored, generated, placeholder, missing, unsupported. |
| mirror provenance | Store generated_from and mirror_x metadata for generated directions. |
| frame sequences | Preserve timing slot count; missing/placeholder slots still count. |
| runtime output | Produce resolved SpriteFrames/AnimationPlayer clips for runtime. |

Preprocess flow:

```md
Authored art
-> SpriteSet source coverage
-> validate action direction policy
-> materialize mirrored clips
-> materialize mirrored hitbox profiles
-> generate runtime SpriteFrames / clips
-> runtime plays resolved assets
```

### <span style="color:#4F9D69"><u><strong>15.2 VisualPresenter Responsibilities</strong></u></span>

| Responsibility | Contract |
| --- | --- |
| clip resolution | Resolve <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">state/move + facing</code> into final clip name. |
| direction policy | Apply <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code>, <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code>, <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code>, <code style="color:#7C65C1;font-weight:700;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">custom</code>. |
| frame sync | Sync MoveRuntime authored frame to SpriteFrames frame. |
| <strong><span style="color:#C65D5D">hitstop</span></strong> freeze | Freeze visible frame during <strong><span style="color:#C65D5D">hitstop</span></strong> without changing MoveData. |
| hit feedback | Play flash/sfx/vfx hooks from HurtResult. |
| health bars | Render fixed HUD and overhead bars. |
| debug overlay | Show hitboxes, hurtboxes, foot anchor, depth key, and missing clip status. |
| fallback | Explicit warning fallback only; silent fallback is <strong><u><span style="color:#C65D5D">forbidden</span></u></strong>. |

Health bar display is presenter style, not LifeRuntime truth.

<pre style="background:#F8FAFC;border:1px solid #E4E7EC;border-radius:8px;padding:0.8em 1em;line-height:1.45;overflow:auto">
<span style="color:#5B677A;font-weight:700">HealthBars</span>
<span style="color:#2F80A8;font-weight:700">|-- placement: overhead / fixed_hud</span>
<span style="color:#2F80A8;font-weight:700">|-- visibility: always / on_damage / selected_only / hidden</span>
<span style="color:#2F80A8;font-weight:700">|-- style: default_yellow / enemy / boss / debug</span>
<span style="color:#2F80A8;font-weight:700">`-- damage_animation: instant / delayed_red_drain</span>
</pre>

Rules:

- Runtime <strong><u><span style="color:#C65D5D">must not</span></u></strong> silently swap missing clips.
- Runtime <strong><u><span style="color:#C65D5D">must not</span></u></strong> create production mirror variants on the fly.
- Preview and runtime must resolve the same final clip names.
- Generated mirror assets are allowed and preferred; storage cost is not a constraint.
- Generated assets must preserve provenance so they are not mistaken for authored art.

## <span style="color:#2F80A8"><u><strong>16. Behavior Catalog</strong></u></span>

<small><em>Genesis 1:21 — Each after its kind.</em></small><br>
<small><em>Genesis 1:25 — Kinds are useful; species explosion is not.</em></small>

| Behavior | Driver | MoveData Category | State Event | Direction Policy | Hitbox | Minimum Visual | Baseline |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">idle</code> | Non-Move State behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_stop</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_finished</code> | <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code> | no | south idle | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">walk</code> | Non-Move State behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_move</code> | <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code> | no | travel walk set | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">run</code> | Non-Move speed variant | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_move</code> | <code style="color:#D48A33;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">full_8flip</code> | no | travel run set | optional |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump</code> | Non-Move State behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_jump</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | no | east jump | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">fall</code> | Non-Move State behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_fall</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | no | east fall | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dash</code> | MoveData when committed | movement / combat | movement event or <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | optional | east dash | optional |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> | MoveData | combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | yes | east punch | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_kick</code> | MoveData | combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | yes | east kick | optional |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">jump_attack</code> | MoveData | combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | yes | east jump_attack | optional |
| <code style="color:#C65D5D;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">360_attack</code> | MoveData | combat | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_attack</code> | <code style="color:#7C65C1;font-weight:700;font-style:italic;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">custom</code> or one readable clip | multi-hitbox | one readable clip | optional |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">hurt</code> | Non-Move reaction behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_hurt</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | no | east hurt | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> | Non-Move terminal behavior | n/a | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code> | <code style="color:#4F9D69;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">single_south</code> | no | south dead | yes |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">block</code> | MoveData when timed/committed | defense | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_block</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | optional counter only | east block | future |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">parry</code> | MoveData when timed/committed | defense | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_parry</code> | <code style="color:#2F80A8;font-weight:700;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">side_2flip</code> | optional counter only | east parry | future |

## <span style="color:#2F80A8"><u><strong>17. Size Contract</strong></u></span>

<small><em>Genesis 6:15 — This is the measure you shall make it.</em></small><br>
<small><em>Ezekiel 40:3 — A measuring reed before a city.</em></small>

<code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">size</code> is a fixed sprite size class, not a free-form character dimension.

| Class | Sprite Body | Frame Canvas | Role |
| --- | --- | --- | --- |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s32</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">32x32</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">48x48</code> | kids / tiny |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s48</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">48x48</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">64x64</code> | small |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s64</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">64x64</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">80x80</code> | default human |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s80</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">80x80</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">96x96</code> | large |
| <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s96</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">96x96</code> | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">112x112</code> | giant |

Rules:

- <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">frame_canvas = sprite_body + 16px action-safe margin</code>.
- Every animation frame must match its class frame canvas.
- Default class is <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">s64</code> / <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">80x80</code> canvas.
- Silent fallback is <strong><u><span style="color:#C65D5D">forbidden</span></u></strong>; log every fallback.

## <span style="color:#2F80A8"><u><strong>18. Z / Occlusion Contract</strong></u></span>

<small><em>Genesis 1:17 — Lights are set for seeing, not for judging collision.</em></small><br>
<small><em>Genesis 1:18 — Rule the display; do not rule the damage.</em></small>

Z is visual only.

| Rule | Contract |
| --- | --- |
| gameplay collision | 2D only; z never affects hit/hurt overlap or damage. |
| depth owner | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">DepthSortSystem</code> at StageRuntime level. |
| depth anchor | foot point / bottom of body collision. |
| render sort | lower screen Y renders in front of higher screen Y. |
| z_index | reserved for layer priority override only. |
| y_sort | allowed for render grouping. |

```md
render_sort_y = global_position.y + foot_offset_y
```

## <span style="color:#2F80A8"><u><strong>19. Genesis Authoring Scene Contract</strong></u></span>

<small><em>Genesis 2:19 — Every living frame needs a name before it enters the world.</em></small><br>
<small><em>Proverbs 24:3 — By wisdom a house is built.</em></small>

Genesis is the official user-facing authoring scene for sprite definition, validation, preview, and export. Its full product design lives in [[New PRD Genesis]].

This main PRD keeps only the boundary contract:

| Item | Rule |
| --- | --- |
| Document split | [[New PRD]] owns world/runtime/gameplay rules. [[New PRD Genesis]] owns the authoring scene and character JSON workflow. |
| Source truth | Every default or user-created character has one <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">SpriteDefinition</code> JSON record. That record is enough to reconstruct its authored character definition when combined with project-level shared rules from this PRD and [[ddd.md]]. |
| Baseline characters | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">origin</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">adam</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">eva</code>, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">cain</code>, and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">solomen</code> are the five required baseline SpriteDefinition records. |
| Runtime boundary | Genesis writes and validates authoring data; gameplay runtime consumes validated data and generated assets. Genesis does not redefine combat, State, MoveData, SpriteSet, or LifeRuntime rules. |
| Preview boundary | Genesis preview uses the same resolver contract as runtime. The preview surface is a toggleable floating window, not gameplay truth. |
| File-size boundary | Genesis details stay in [[New PRD Genesis]] to keep this PRD readable and maintainable. |

Rules:

- Genesis <strong><u><span style="color:#C65D5D">must not</span></u></strong> silently create hidden gameplay data outside the character JSON.
- Genesis may generate rebuildable assets and validation reports, but generated assets are not source truth.
- Genesis may expose user-friendly controls, but saved data must stay compatible with [[ddd.md]] field ownership.

## <span style="color:#2F80A8"><u><strong>20. Validation Contract</strong></u></span>

<small><em>Deuteronomy 19:15 — Two or three witnesses establish the matter.</em></small><br>
<small><em>Proverbs 20:10 — Unequal weights are an abomination to QA.</em></small>

| Area | Required Checks |
| --- | --- |
| World | resolution, texture filter, size class, frame canvas size |
| Direction | action policy satisfied; south/north <strong><u><span style="color:#C65D5D">never mirrored</span></u></strong>; generated mirror provenance present |
| SpriteSet | clips exist, frame sequences preserve slot count, missing/placeholder/unsupported status explicit |
| Source Truth | only [[New PRD]] and [[ddd]] are authoritative; historical PRDs/data/runtime files are reference only |
| MoveData | frame windows, segment gates, input command, hitbox profiles, ATK values, finish events |
| Combat | hitbox id validity, hurtbox DEF default <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code>, formula-only final damage, one-hit rule, multi_hit rules, segmented attack instance rules |
| Runtime | selected instance reports state/move/segment/frame/HP/input buffer/hurt_result; preview/runtime resolver parity |
| Death | HP reaching zero emits <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code> and StateDriver enters <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code> |
| Assets | generated SpriteFrames/clips exist and are fresh relative to source coverage |

Required smoke level:

```md
schema validation
source-truth boundary validation
SpriteSet coverage validation
preprocess mirror validation
runtime clip resolver validation
input buffer / segmented combo gate smoke
hitbox / hurtbox / damage formula smoke
hitstop / hitstun metadata placeholder smoke
death event + dead state smoke
Genesis save / reload / preview smoke
```

## <span style="color:#2F80A8"><u><strong>21. Implementation Path / Technical Route</strong></u></span>

<small><em>Nehemiah 4:17 — Build with one hand; hold the sword with the other.</em></small><br>
<small><em>Proverbs 21:5 — Diligent plans lead to plenty; giant frameworks lead to chores.</em></small>

Implement in narrow vertical slices. Each slice must be playable or visibly verifiable.

| Step | Deliverable | Pass Condition |
| --- | --- | --- |
| 0 | Plugin/readiness inventory | LimboAI availability, Godot primitive usage, current smoke baseline, no assumed green. |
| 1 | Adam runtime skeleton | Adam spawns with CollisionBody, StateDriver, RuntimeBlackboard, VisualPresenter idle clip. |
| 2 | InputSystem slice | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">D</code> movement, <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">J -&gt; attack_light</code>, pre-input buffer, and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> intent visible in debug. |
| 3 | MoveRuntime slice | <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch</code> single-segment and <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">basic_punch_3hit</code> segmented startup/active/recovery/gate/finish run by authored frames. |
| 4 | CombatPorts + CombatResolver | HitboxSource hits HurtboxReceiver once; damage = <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">max(0, hitbox_atk - selected_hurtbox_def)</code>, with omitted DEF = <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">0</code>. |
| 5 | LifeRuntime + Visual health bars | HP reduces; HP <= 0 emits observable <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">ev_dead</code>; StateDriver enters <code style="color:#475467;font-weight:500;background:#F3F6FA;border:1px solid #D9E2EC;border-radius:4px;padding:0 0.18em">dead</code>; bars render with delayed red drain style. |
| 6 | VisualPresenter parity | SpriteSet direction policy, generated mirrors, frame sync, <strong><span style="color:#C65D5D">hitstop</span></strong> metadata/freeze behavior, missing warnings match preview/runtime. |
| 7 | DepthSortSystem | foot-Y sort/z_index works for Adam + NPC without affecting hit detection. |
| 8 | SpawnResetSystem | spawn/reset binds template + SpriteSet + equipped systems; Playground can restart slice fast. |
| 9 | Genesis scene baseline | DefinitionNavigator + DetailEditor + toggleable FloatingPreviewWindow + ValidationDrawer edit and validate one SpriteDefinition JSON path. |
| 10 | Community code decision | Fray input code and cluttered-code spike are either vendored with license or rejected with notes. |

Technical route:

| Area | Route |
| --- | --- |
| State | LimboAI first; keep current custom state loop only as fallback until spike passes. |
| Input | Study Fray input GDScript; copy the useful buffer/sequence logic if smaller than custom writing. |
| Hit/Hurt/Health plugin | Spike cluttered-code only against our flow; reject if it bypasses CombatResolver/HurtResult or causes multi-hit ambiguity. |
| Combat | Own CombatResolver; keep formula simple and testable. |
| Visual | Own VisualPresenter; this is SpriteSet-specific glue, not a reusable engine. |
| UI | Godot Control nodes; no plugin unless a direct pain appears. |
| Verification | Prefer headless smoke scripts plus Genesis visual review. |

## <span style="color:#2F80A8"><u><strong>22. Baseline Scope</strong></u></span>

<small><em>Genesis 2:16 — You may freely eat; not from every tree.</em></small><br>
<small><em>Ecclesiastes 7:16 — Do not be overwise; ship the slice.</em></small>

### <span style="color:#4F9D69"><u><strong>22.1 Minimum Playable Sprite</strong></u></span>

```md
idle
walk
jump
fall
basic_punch
hurt
dead
```

### <span style="color:#4F9D69"><u><strong>22.2 Allowed Next Moves</strong></u></span>

```md
run
dash
basic_kick
basic_punch_3hit
jump_attack
360_attack
block
parry
```

### <span style="color:#4F9D69"><u><strong>22.3 Out of Scope</strong></u></span>

```md
General 2D engine
Weapon framework
Projectile framework
Paper-doll wardrobe system
Full combo tree engine
Physics-based ragdoll
Directional south/north baseline attacks
Runtime-only production mirror
Raw sprite editing inside Genesis
Multiplayer
```

## <span style="color:#2F80A8"><u><strong>23. One-Line Definition</strong></u></span>

<small><em>Genesis 1:31 — Behold, it is very good enough.</em></small><br>
<small><em>Genesis 11:6 — One language, one toolchain, fewer towers.</em></small>

SpritesPlayground is a constrained Godot/LimboAI 2D pixel ACT playground: minimal actor systems, clear stage services, strict data ownership, preprocessed swappable sprites, and arcade-quality feel through input buffer, cancel timing, <strong><span style="color:#C65D5D">hitstop</span></strong>, simple hitbox math, and readable hit reactions.
