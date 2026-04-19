#!/bin/bash
# Evolved Athlete — Claude Code Setup
# Run this once on a new Mac to get fully configured.
# Usage: bash setup.sh

set -e

# ── Colors ──────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
hr()   { echo ""; echo "──────────────────────────────────────"; echo ""; }

# Read from /dev/tty so prompts work when the script is piped (e.g. curl|bash).
# Without this, `read` consumes the script itself as "user input" — which has
# bitten us before (directories ended up named after literal bash source lines).
# Usage: ask VAR "prompt" "default_value"
ask() {
  local __var="$1"; local __prompt="$2"; local __default="$3"
  local __value=""
  if [ -r /dev/tty ]; then
    read -p "$__prompt" __value < /dev/tty || __value=""
  fi
  printf -v "$__var" '%s' "${__value:-$__default}"
}

# ── Header ───────────────────────────────────────────────────────────────
clear
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   Evolved Athlete — Claude Setup     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  This script will:"
echo "  • Install Claude Code"
echo "  • Clone your knowledge base (kb)"
echo "  • Install all plugins (main-branch, hormozi, ladder)"
echo "  • Connect Notion and Google Drive"
echo "  • Set up your global Claude config"
echo ""
echo "  Takes about 5 minutes. You'll need:"
echo "  • A Claude Max subscription (claude.ai)"
echo "  • Your GitHub credentials"
echo ""
ask _ "  Ready? Press Enter to start..." ""

# ── Prerequisites: git ───────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  hr
  echo "INSTALLING GIT (Xcode Command Line Tools)"
  echo ""
  echo "  Git isn't installed yet. A popup will appear asking you to install"
  echo "  'Xcode Command Line Tools' — click Install and wait for it to finish."
  echo "  This takes 2–5 minutes. Come back here when it's done."
  echo ""
  xcode-select --install 2>/dev/null || true
  echo ""
  ask _ "  Done installing? Press Enter to continue..." ""
  if ! command -v git &>/dev/null; then
    fail "git still not found. Restart Terminal and run this script again."
  fi
  ok "git installed"
fi

# ── Step 1: Where should everything live? ───────────────────────────────
hr
echo "STEP 1 OF 7: Choose your home base"
echo ""
echo "Where should your GitHub repos live on this Mac?"
echo "(This is where kb, and future repos will be cloned.)"
echo ""
ask GITHUB_DIR "  Path [~/Documents/GitHub]: " "$HOME/Documents/GitHub"
GITHUB_DIR="${GITHUB_DIR/#\~/$HOME}"

mkdir -p "$GITHUB_DIR"
ok "Using: $GITHUB_DIR"

KB_PATH="$GITHUB_DIR/kb"

# ── Step 2: Install Claude Code ─────────────────────────────────────────
hr
echo "STEP 2 OF 7: Install Claude Code"
echo ""

if command -v claude &>/dev/null; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
else
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash

  # Fix PATH for current shell and future shells
  SHELL_RC=""
  if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
  else
    SHELL_RC="$HOME/.bashrc"
  fi

  if ! grep -q '.local/bin' "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
  fi
  export PATH="$HOME/.local/bin:$PATH"

  if command -v claude &>/dev/null; then
    ok "Claude Code installed"
  else
    fail "Claude Code installation failed. Try running: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# ── Step 3: Clone knowledge base ────────────────────────────────────────
hr
echo "STEP 3 OF 7: Clone your knowledge base"
echo ""

# Heal legacy garbage paths from the pre-/dev/tty setup.sh bug, where `read`
# under curl|bash consumed the next script line. mkdir -p on the resulting
# literal string created a nested garbage chain like:
#   ~/GITHUB_DIR="${GITHUB_DIR:-$HOME/Documents/GitHub}"/Documents/GitHub}"/kb
# (because bash treats embedded `/` chars as path separators).
#
# Scan $HOME (bounded depth) for any kb that has .git and looks like ours
# (contains CLAUDE.md), is not at $KB_PATH, and migrate it. Then walk up the
# garbage parent chain rmdir'ing empty dirs until we hit a real directory.
if [ ! -d "$KB_PATH/.git" ]; then
  legacy_kb=""
  while IFS= read -r candidate; do
    if [ -d "$candidate/.git" ] \
       && [ -f "$candidate/CLAUDE.md" ] \
       && [ "$candidate" != "$KB_PATH" ]; then
      legacy_kb="$candidate"
      break
    fi
  done < <(find "$HOME" -maxdepth 6 -type d -name kb 2>/dev/null)

  if [ -n "$legacy_kb" ]; then
    info "Found existing kb at non-canonical path: $legacy_kb"
    info "Migrating to: $KB_PATH"
    mkdir -p "$(dirname "$KB_PATH")"
    # Move kb
    if [ -d "$KB_PATH" ] && [ -z "$(ls -A "$KB_PATH")" ]; then rmdir "$KB_PATH"; fi
    mv "$legacy_kb" "$KB_PATH"
    ok "Moved kb → $KB_PATH"

    # Move brandon-personal if it was in the same garbage parent
    legacy_parent="$(dirname "$legacy_kb")"
    if [ -d "$legacy_parent/brandon-personal" ] && [ ! -d "$GITHUB_DIR/brandon-personal" ]; then
      mv "$legacy_parent/brandon-personal" "$GITHUB_DIR/brandon-personal"
      ok "Moved brandon-personal → $GITHUB_DIR/brandon-personal"
    fi

    # Walk up the garbage parent chain, rmdir'ing each empty dir.
    # Stops at $HOME, $HOME/Documents, or $GITHUB_DIR as a safety net.
    cleanup="$legacy_parent"
    while [ -d "$cleanup" ] \
       && [ -z "$(ls -A "$cleanup" 2>/dev/null)" ] \
       && [ "$cleanup" != "$HOME" ] \
       && [ "$cleanup" != "$HOME/Documents" ] \
       && [ "$cleanup" != "$GITHUB_DIR" ]; do
      rmdir "$cleanup" 2>/dev/null || break
      ok "Removed empty garbage dir: $cleanup"
      cleanup="$(dirname "$cleanup")"
    done
  fi
fi

if [ -d "$KB_PATH/.git" ]; then
  ok "kb already exists at $KB_PATH"
else
  # If a prior failed run left an empty dir, remove it so git clone works
  if [ -d "$KB_PATH" ] && [ -z "$(ls -A "$KB_PATH")" ]; then
    rmdir "$KB_PATH"
  fi

  info "Cloning evolved-athlete/kb..."
  if git clone https://github.com/evolved-athlete/kb.git "$KB_PATH"; then
    ok "Cloned to $KB_PATH"
  else
    echo ""
    echo "  Clone failed. The kb repo is private — you need GitHub auth first."
    echo ""
    echo "  Fix:"
    echo "    1. Install GitHub CLI if you don't have it:"
    echo "         brew install gh   (needs Homebrew — see brew.sh)"
    echo "       or download the .pkg from https://cli.github.com"
    echo "    2. Authenticate:"
    echo "         gh auth login"
    echo "       (choose GitHub.com → HTTPS → login with a web browser)"
    echo "    3. Re-run this setup script."
    echo ""
    fail "Cannot continue without a cloned kb."
  fi
fi

# ── Step 4: Configure main-branch plugin ────────────────────────────────
hr
echo "STEP 4 OF 7: Configure plugins"
echo ""

# Write main-branch config (plain YAML — no Python deps)
mkdir -p "$HOME/.config/main-branch"
cat > "$HOME/.config/main-branch/config.yaml" <<EOF
repo_path: "$KB_PATH"
EOF
ok "main-branch config → $KB_PATH"

# Install Claude Code global config and statusline
mkdir -p "$HOME/.claude"
BASE_URL="https://raw.githubusercontent.com/evolved-athlete/claude/main"

if curl -fsSL "$BASE_URL/CLAUDE.md" -o "$HOME/.claude/CLAUDE.md"; then
  ok "Global CLAUDE.md installed"
else
  warn "Could not download global CLAUDE.md — set it up manually from github.com/evolved-athlete/claude"
fi

if curl -fsSL "$BASE_URL/statusline.sh" -o "$HOME/.claude/statusline.sh"; then
  chmod +x "$HOME/.claude/statusline.sh"
  # Wire it into Claude Code settings (json is Python stdlib — no extra deps)
  if python3 - <<'PYEOF'
import json, os
settings_path = os.path.expanduser('~/.claude/settings.json')
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except Exception:
        pass
# Claude Code expects statusLine as an object, not a bare string path.
settings['statusLine'] = {
    'type': 'command',
    'command': os.path.expanduser('~/.claude/statusline.sh'),
}
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  then
    ok "Statusline installed"
  else
    warn "Downloaded statusline but couldn't wire it into settings.json — add 'statusLine' manually to ~/.claude/settings.json"
  fi
else
  warn "Could not download statusline — skipping"
fi

# Add plugin marketplaces
info "Adding evolved-athlete plugin marketplace..."
if claude plugin marketplace add evolved-athlete/skills; then
  ok "evolved-athlete marketplace added"
else
  warn "Could not add evolved-athlete marketplace (may already exist)"
fi

info "Adding anthropics/claude-plugins-official marketplace..."
if claude plugin marketplace add anthropics/claude-plugins-official; then
  ok "claude-plugins-official marketplace added"
else
  warn "Could not add claude-plugins-official marketplace (may already exist)"
fi

# Install plugins
echo ""
info "Installing plugins..."

for plugin in "main-branch@evolved-athlete" "hormozi@evolved-athlete" "ladder@evolved-athlete" "notion@claude-plugins-official"; do
  if claude plugin install "$plugin"; then
    ok "Installed $plugin"
  else
    warn "Could not install $plugin — run 'claude plugin install $plugin' manually"
  fi
done

# ── Step 5: MCP servers ──────────────────────────────────────────────────
hr
echo "STEP 5 OF 7: Connect MCP servers"
echo ""

# Google Drive
info "Adding Google Drive MCP..."
if claude mcp add gdrive -- npx -y @modelcontextprotocol/server-gdrive; then
  ok "Google Drive MCP added (you'll authenticate on first use)"
else
  warn "Could not add Google Drive MCP automatically"
fi

# ── Step 6: Personal folder (ladder) ────────────────────────────────────
hr
echo "STEP 6 OF 7: Create personal tracking folder"
echo ""

PERSONAL_PATH="$GITHUB_DIR/brandon-personal"
mkdir -p "$PERSONAL_PATH/ladder/goals"
mkdir -p "$PERSONAL_PATH/ladder/log/weekly"
ok "Personal folder created at $PERSONAL_PATH"

# ── Step 7: Summary ──────────────────────────────────────────────────────
hr
echo "STEP 7 OF 7: Manual steps remaining"
echo ""
echo "  The script handles everything it can automatically."
echo "  Three things still need you in a browser:"
echo ""
echo "  ${YELLOW}1. Chrome extension${NC}"
echo "     Go to: chrome.google.com/webstore"
echo "     Search: 'Claude for Chrome' (by Anthropic)"
echo ""
echo "  ${YELLOW}2. Notion${NC}"
echo "     Start a Claude session and run /Notion:search"
echo "     It will prompt you to connect your workspace."
echo ""
echo "  ${YELLOW}3. Google Drive${NC}"
echo "     Start a Claude session and ask to access a Drive file."
echo "     A browser window will open for Google sign-in."
echo ""
hr
echo "  ${GREEN}You're set up. Here's how to start:${NC}"
echo ""
echo "  ${BLUE}Business work:${NC}"
echo "    cd $KB_PATH"
echo "    claude"
echo "    /start"
echo ""
echo "  ${BLUE}Personal (goals + accountability):${NC}"
echo "    cd $PERSONAL_PATH"
echo "    claude"
echo "    /climb"
echo ""
echo "  ${BLUE}Use Hormozi frameworks:${NC}"
echo "    /hormozi [describe what you're building or evaluating]"
echo ""
hr
