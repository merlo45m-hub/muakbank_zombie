#!/bin/bash
# Pre-commit check — runs before every commit
# Blocks commit if validation fails
# Usage: bash tools/pre_commit_check.sh

PROJECT="/storage/emulated/0/Games/Muakbank_zombie"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

echo "========================================"
echo "  Pre-Commit Check"
echo "========================================"
echo ""

# 1. Git health check
echo -n "[1/4] Git health check ... "
if bash "$PROJECT/tools/git_health_check.sh" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ FAIL — do not commit${NC}"
    ((FAIL++))
fi

# 2. Static project validation
echo -n "[2/4] Project validator ... "
if python3 "$PROJECT/tools/validate_project.py" 2>&1 | grep -q "ISSUES: 0"; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS++))
elif [ ! -f "$PROJECT/tools/validate_project.py" ]; then
    echo -e "${YELLOW}⚠ SKIP — validator not found${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ FAIL — do not commit${NC}"
    ((FAIL++))
fi

# 3. No untracked sensitive files
echo -n "[3/4] Sensitive files check ... "
SENSITIVE=$(git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" status --short 2>&1 | grep -E "\.git-credentials|\.env|id_ed25519|\.ssh" || true)
if [ -z "$SENSITIVE" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ FAIL — sensitive files staged:${NC}"
    echo "$SENSITIVE"
    ((FAIL++))
fi

# 4. No Godot 3 API usage in new/changed scripts
echo -n "[4/4] Godot 3 API scan ... "
CHANGED=$(git --git-dir="$PROJECT/.git" --work-tree="$PROJECT" diff --name-only HEAD 2>/dev/null || find "$PROJECT/scripts" -name "*.gd" -newer "$PROJECT/project.godot" 2>/dev/null)
if [ -n "$CHANGED" ]; then
    GDOT3=$(grep -rn "Spatial\|KinematicBody\|AnimationPlayer.*stop_playing\|get_node_or_null.*cut_tree\|CanvasLayer.*layer.*=" $PROJECT/scripts/ 2>/dev/null | grep -v ".import" | head -5 || true)
    if [ -z "$GDOT3" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL — Godot 3 API detected:${NC}"
        echo "$GDOT3"
        ((FAIL++))
    fi
else
    echo -e "${GREEN}✓ PASS (no changes to scan)${NC}"
    ((PASS++))
fi

echo ""
echo "========================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC} / ${RED}${FAIL} failed${NC}"
echo "========================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "${RED}COMMIT BLOCKED — fix failures above${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All checks passed — safe to commit${NC}"
exit 0
