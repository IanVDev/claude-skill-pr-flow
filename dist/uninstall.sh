#!/usr/bin/env bash
# uninstall.sh — remove a skill pr-flow de ~/.claude/skills/.
# Preserva backups anteriores (pr-flow.backup.*) — remova manualmente se quiser.

set -euo pipefail

TARGET="${HOME}/.claude/skills/pr-flow"

if [ ! -d "$TARGET" ]; then
  echo "pr-flow nao esta instalada em $TARGET — nada a fazer."
  exit 0
fi

BACKUP="${TARGET}.uninstalled.$(date +%Y%m%d%H%M%S)"
mv "$TARGET" "$BACKUP"
echo "pr-flow removida. Backup em $BACKUP (delete manualmente se nao precisar)."
