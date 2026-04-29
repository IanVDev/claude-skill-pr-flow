#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR="$HOME/.claude/skills/pr-flow"
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "pr-flow removida de $INSTALL_DIR"
else
  echo "pr-flow nao encontrada em $INSTALL_DIR"
fi
