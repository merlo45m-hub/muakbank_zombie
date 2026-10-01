# Muakbank Zombie — Anti-Slop Principles

These principles govern all code, UI, and design decisions in this project. They are not optional.

## Core Philosophy

Avoid statistical averages. Every decision must be specific to this game, this player, this platform. If a choice could be lifted verbatim into another game and still read as correct, it is wrong.

## Code Quality

- **No god functions** — if a function does more than one thing, split it
- **No copy-paste with slight variations** — abstract, parameterize
- **No unused imports or properties** — delete them
- **No `console.log` in production** — use proper logging or remove
- **No magic numbers** — name constants, explain why
- **No overly descriptive comments** — comments explain WHY, not WHAT
- **No scratch files in the repo** — delete before calling it done

## UI/UX

- **No emoji as icons** — use real icons or text
- **No generic button copy** — every button states exactly what it does
- **No click targets < 44x44px** — mobile usability minimum
- **No hover-only interactions** — touch devices have no hover
- **No uniform padding** — rhythm varies by context
- **No decorative gradients by default** — only if they serve the design

## Mobile-Specific

- **Touch-first** — every interaction must work with thumbs
- **Thumb zone** — primary actions in the bottom 2/3 of the screen
- **No hover states** — they don't exist on touch
- **No tiny text** — minimum 14sp for body, 16sp for interactive
- **No multi-touch conflicts** — joystick + camera + buttons must not fight

## Workflow

1. Describe architecture + list files to touch
2. State assumptions
3. Make ONE small change
4. F6 the relevant test scene
5. Test on Android
6. Checkpoint commit if good, revert if broken

## Self-Check

Before showing any output:
1. Is this specific to Muakbank Zombie?
2. Did I choose this because it is right, or because it was first?
3. Is there a concrete fact driving this choice?
4. Would a 40-year practitioner ship this?
5. Have I said what this is NOT going to do?
6. Is there anything here only because I thought it was expected?
