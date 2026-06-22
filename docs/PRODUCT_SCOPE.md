# Product Scope

## Product Name

**Miduo Character Combat Lab** inside the `SpritesPlayground` repository.

## One-line Definition

A Godot internal playground for validating limited, template-based pixel characters, moves, hitboxes, hurtboxes, HP, and state-machine behavior before assets enter the real Miduo game.

## Do

- Maintain fixed sprite size classes: `s48`, `s64`, `s80`, `s96`.
- Use locked gray base templates as calibration models.
- Create new character templates by copying/composing profiles.
- Support character-local hurtboxes:
  - `hurt_head`
  - `hurt_upper_body`
  - `hurt_lower_body`
- Support move-owned hitboxes:
  - `hit_head`
  - `hit_fist_1`, optional `hit_fist_2`
  - `hit_leg_1`, optional `hit_leg_2`
  - `hit_projectile` reserved but not active in MVP
- Support one editable foot collision ellipse per character.
- Support HP-only red health system.
- Support manual and AI playground testing.
- Support base movement actions: `idle`, `walk`, `dash`, `jump`, `hurt`, `dead`.
- Support base attack moves: `basic_punch`, `basic_kick`.
- Support extension moves later via equipped move sets.

## Do Not Do In MVP

- No weapon system.
- No projectile/flying-object system.
- No stamina system.
- No mana/blue/magic system.
- No full combo system.
- No formal beat-em-up level.
- No full shop/economy.
- No single-piece wardrobe/dress-up system.
- No deep inheritance template system.
- No skeleton/bone/body-anchor system.

## Product Boundary

This is not the final game. It is the character production and validation lab.
