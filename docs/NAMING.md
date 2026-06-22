# Naming Rules

## General

Use lowercase snake_case.

Good:

```text
combat_gray_s64
basic_punch
hit_fist_1
hurt_upper_body
```

Avoid:

```text
CombatGray
basicPunch
HitFist01
hurtUpperBody
```

## Sprite Size Classes

```text
s48
s64
s80
s96
```

## Character Templates

```text
base_gray_s64
combat_gray_s64
miduo_s64
dad_s80
mama_s96
dog_s48
```

## Profiles

```text
humanoid_s64_hurtbox
humanoid_s64_foot
child_hp_default
adult_hp_default
```

## Hurtboxes

```text
hurt_head
hurt_upper_body
hurt_lower_body
```

## Hitboxes

```text
hit_head
hit_fist_1
hit_fist_2
hit_leg_1
hit_leg_2
hit_projectile
```

`hit_projectile` is reserved and not active in MVP.

## States

```text
idle
walk
dash
jump
attack
hurt
dead
```

## Moves

Base movement:

```text
idle
walk
dash
jump
hurt
dead
```

Base attacks:

```text
basic_punch
basic_kick
```

Future extension examples:

```text
cross_punch
heavy_punch
round_kick
dash_attack
jump_attack
```
