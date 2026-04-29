#!/usr/bin/env bash
# pr-flow installer — valida checksum antes de extrair.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SCRIPT_DIR/pr-flow.skill"
MANIFEST="$SCRIPT_DIR/manifest.json"
INSTALL_DIR="$HOME/.claude/skills/pr-flow"

echo "==> Validando checksum..."
EXPECTED=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['artifact_sha256'])")
ACTUAL=$(sha256sum "$SKILL_FILE" | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "ERRO: checksum invalido. Esperado: $EXPECTED / Obtido: $ACTUAL"
  exit 1
fi
echo "    OK: $ACTUAL"

echo "==> Instalando em $INSTALL_DIR"
mkdir -p "$HOME/.claude/skills"
rm -rf "$INSTALL_DIR"
tar xzf "$SKILL_FILE" -C "$HOME/.claude/skills/"

echo ""
echo "pr-flow instalada em $INSTALL_DIR"
echo "Reinicie o Claude Code para detectar a skill."
