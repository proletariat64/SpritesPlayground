# Separate eight-direction locomotion from two-facing actions

Characters use eight compass directions for idle, walk, and run presentation, while dash, jump, hurt, death, and attacks retain persistent east-or-west combat facing. Eden supplies complete eight-direction locomotion art but only east/west action art; separating locomotion direction from combat facing uses the authored assets without inventing missing action directions or changing combat geometry.

## Consequences

Locomotion direction follows movement intent and persists while stationary. Two-facing actions preserve the prior horizontal combat facing, and legacy sprite sets may fall back to unsuffixed animations.
