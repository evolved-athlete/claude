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
read -p "  Ready? Press Enter to start..." _

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
  read -p "  Done installing? Press Enter to continue..." _
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
read -p "  Path [~/Documents/GitHub]: " GITHUB_DIR
GITHUB_DIR="${GITHUB_DIR:-$HOME/Documents/GitHub}"
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

if [ -d "$KB_PATH/.git" ]; then
  ok "kb already exists at $KB_PATH"
else
  info "Cloning evolved-athlete/kb..."
  if git clone https://github.com/evolved-athlete/kb.git "$KB_PATH" 2>/dev/null; then
    ok "Cloned to $KB_PATH"
  else
    warn "Could not clone kb automatically."
    echo ""
    echo "  You may need to authenticate with GitHub first."
    echo "  After this script finishes, run:"
    echo ""
    echo "    gh auth login"
    echo "    git clone https://github.com/evolved-athlete/kb.git $KB_PATH"
    echo ""
    # Create the directory anyway so config can be written
    mkdir -p "$KB_PATH"
    warn "Created empty $KB_PATH — clone it manually after authenticating."
  fi
fi

# ── Step 4: Configure main-branch plugin ────────────────────────────────
hr
echo "STEP 4 OF 7: Configure plugins"
echo ""

# Write main-branch config
mkdir -p "$HOME/.config/main-branch"
python3 - <<PYEOF
import yaml, os
config = {'repo_path': '$KB_PATH'}
with open(os.path.expanduser('~/.config/main-branch/config.yaml'), 'w') as f:
    yaml.dump(config, f)
PYEOF
ok "main-branch config → $KB_PATH"

# Install Claude Code global config
mkdir -p "$HOME/.claude"
CONFIG_SRC="https://raw.githubusercontent.com/evolved-athlete/claude/main/CLAUDE.md"
if curl -fsSL "$CONFIG_SRC" -o "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
  ok "Global CLAUDE.md installed"
else
  warn "Could not download global CLAUDE.md — set it up manually from github.com/evolved-athlete/claude"
fi

# Add evolved-athlete marketplace
info "Adding evolved-athlete plugin marketplace..."
if claude plugin marketplace add evolved-athlete/skills 2>/dev/null; then
  ok "evolved-athlete marketplace added"
else
  warn "Could not add evolved-athlete marketplace (may already exist)"
fi

# Install plugins
echo ""
info "Installing plugins..."

for plugin in "main-branch@evolved-athlete" "hormozi@evolved-athlete" "ladder@evolved-athlete" "Notion@claude-plugins-official"; do
  if claude plugin install "$plugin" 2>/dev/null; then
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
if claude mcp add gdrive -- npx -y @modelcontextprotocol/server-gdrive 2>/dev/null; then
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
