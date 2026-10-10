# Branch Workflow

## Rules
- `main` is always deployable — never commit broken code to main
- Feature branches for anything beyond a typo fix
- Branch naming: `feat/<name>`, `fix/<name>`, `chore/<name>`, `docs/<name>`
- Merge back to main via PR on GitHub (even solo — gives a review checkpoint)

## Common Branches
- `feat/interactive-props` — interactive door/vehicle/wall system (merged)
- `fix/character-stats` — wire up character_stats to Player.gd (pending)
- `fix/char-select-overwrite` — stop CharacterSelect forcing doctor on entry (pending)

## Workflow
```bash
# Create branch
git checkout -b feat/my-feature

# Work, commit, push
git add .
git commit -m "feat: description"
git push origin feat/my-feature

# On GitHub: create PR → merge → delete branch

# Back on main
git checkout main
git pull origin main
git branch -d feat/my-feature  # local cleanup
```

## When to Use Main Directly
- Typo fixes in .md files
- .gitignore updates
- Timestamp/author updates in config files
