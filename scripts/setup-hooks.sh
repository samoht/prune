#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up git hooks...${NC}"

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_ROOT/.git/hooks"

# Create pre-commit hook
cat > "$GIT_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Make sure we're in the project root
cd "$(git rev-parse --show-toplevel)" || exit 1

echo "Running pre-commit checks..."

# 1. Run dune build
echo -e "\n${YELLOW}Running dune build...${NC}"
if ! dune build; then
    echo -e "${RED}❌ Build failed. Please fix build errors before committing.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Build passed!${NC}"

# 2. Run dune fmt
echo -e "\n${YELLOW}Running dune fmt --auto-promote...${NC}"
dune fmt --auto-promote
if ! git diff --quiet; then
    echo -e "${RED}❌ Code formatting changed files. Please stage the formatted files and commit again.${NC}"
    echo "   Run: git add -u && git commit"
    exit 1
fi
echo -e "${GREEN}✅ Code formatting check passed!${NC}"

# 3. Run tests
echo -e "\n${YELLOW}Running dune test...${NC}"
if ! dune test; then
    echo -e "${RED}❌ Tests failed. Please fix failing tests before committing.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Tests passed!${NC}"

# 4. Run merlint (if available in current project)
if [ -f "bin/main.ml" ] && grep -q "merlint" "bin/dune" 2>/dev/null; then
    echo -e "\n${YELLOW}Running merlint analysis...${NC}"
    # Exclude test samples directory since those are intentionally bad code
    if ! dune exec -- merlint --exclude "test/samples/*"; then
        echo -e "${RED}❌ Merlint found issues. Please fix them before committing.${NC}"
        echo "   To bypass this check (not recommended), use: git commit --no-verify"
        exit 1
    fi
    echo -e "${GREEN}✅ Merlint checks passed!${NC}"
fi

# 5. Run prune (if available) only in lib and bin directories
if command -v prune >/dev/null 2>&1; then
    echo -e "\n${YELLOW}Running prune to check for unused code...${NC}"
    # Run prune in dry-run mode to check for unused code
    if ! prune clean lib bin --dry-run; then
        echo -e "${YELLOW}⚠️  Prune found unused code. Consider running 'prune clean lib bin -f' to remove it.${NC}"
        # Don't fail on prune warnings - it's informational only
    else
        echo -e "${GREEN}✅ No unused code found by prune!${NC}"
    fi
fi

# 6. Check for AI attributions
echo -e "\n${YELLOW}Checking commit message for AI attributions...${NC}"
COMMIT_MSG_FILE=".git/COMMIT_EDITMSG"
if [ -f "$COMMIT_MSG_FILE" ]; then
    if grep -E "(Co-authored-by:.*Claude|Co-authored-by:.*GPT|Co-authored-by:.*AI|🤖|Generated with|AI-generated)" "$COMMIT_MSG_FILE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Commit message contains AI/Claude attribution.${NC}"
        echo "Please remove AI-related attributions from your commit message."
        echo "Found pattern: $(grep -E "(Co-authored-by:.*Claude|Co-authored-by:.*GPT|Co-authored-by:.*AI|🤖|Generated with|AI-generated)" "$COMMIT_MSG_FILE" | head -1)"
        exit 1
    fi
fi

echo -e "\n${GREEN}All pre-commit checks passed! ✨${NC}"
EOF

# Create commit-msg hook
cat > "$GIT_ROOT/.git/hooks/commit-msg" << 'EOF'
#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color

COMMIT_MSG_FILE="$1"

# Check for AI attributions in commit message
if grep -E "(Co-authored-by:.*Claude|Co-authored-by:.*GPT|Co-authored-by:.*AI|🤖|Generated with|AI-generated)" "$COMMIT_MSG_FILE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Commit message contains AI/Claude attribution.${NC}"
    echo "Please remove AI-related attributions from your commit message."
    echo "Found pattern: $(grep -E "(Co-authored-by:.*Claude|Co-authored-by:.*GPT|Co-authored-by:.*AI|🤖|Generated with|AI-generated)" "$COMMIT_MSG_FILE" | head -1)"
    exit 1
fi
EOF

# Make hooks executable
chmod +x "$GIT_ROOT/.git/hooks/pre-commit"
chmod +x "$GIT_ROOT/.git/hooks/commit-msg"

echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo
echo "The following hooks have been installed:"
echo "  - pre-commit: Runs dune build, fmt, test, merlint (if available), and prune (if available)"
echo "  - commit-msg: Checks for AI attributions in commit messages"
echo
echo -e "${YELLOW}Note:${NC} The hooks are installed in .git/hooks/ and are not tracked by git."
echo "Run this script on each clone of the repository to set up the hooks."