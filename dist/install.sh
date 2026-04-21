#!/usr/bin/env bash
# install.sh — instala a skill pr-flow em ~/.claude/skills/.
#
# Uso:
#   ./install.sh                                # instala a partir do .skill vizinho
#   ./install.sh /caminho/para/pr-flow.skill    # instala a partir de outro caminho
#
# Idempotente: se pr-flow ja estiver instalada, atualiza no lugar apos confirmar.

set -euo pipefail

SKILL_DIR="${HOME}/.claude/skills"
NAME="pr-flow"
TARGET="${SKILL_DIR}/${NAME}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
ARTIFACT="${1:-${SCRIPT_DIR}/pr-flow.skill}"
MANIFEST="${SCRIPT_DIR}/manifest.json"

if [ ! -f "$ARTIFACT" ]; then
  echo "ERRO: nao encontrei $ARTIFACT" >&2
  echo "Uso: $0 [caminho/para/pr-flow.skill]" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1) Validacao de checksum (se manifest disponivel)
# ---------------------------------------------------------------------------
if [ -f "$MANIFEST" ] && command -v python3 >/dev/null 2>&1; then
  EXPECTED=$(python3 -c "import json,sys; print(json.load(open('$MANIFEST')).get('artifact_sha256',''))")
  if [ -n "$EXPECTED" ]; then
    ACTUAL=$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')
    if [ "$ACTUAL" != "$EXPECTED" ]; then
      echo "ERRO: checksum nao bate" >&2
      echo "  esperado: $EXPECTED" >&2
      echo "  atual:    $ACTUAL" >&2
      echo "Artefato corrompido ou adulterado. Abortando." >&2
      exit 2
    fi
    echo "==> checksum OK ($ACTUAL)"
  fi
fi

# ---------------------------------------------------------------------------
# 2) Backup de instalacao existente
# ---------------------------------------------------------------------------
if [ -d "$TARGET" ]; then
  BACKUP="${TARGET}.backup.$(date +%Y%m%d%H%M%S)"
  echo "==> pr-flow ja instalada. Movendo para $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

# ---------------------------------------------------------------------------
# 3) Extrair
# ---------------------------------------------------------------------------
mkdir -p "$SKILL_DIR"
echo "==> extraindo em $SKILL_DIR"
tar xzf "$ARTIFACT" -C "$SKILL_DIR"

# ---------------------------------------------------------------------------
# 4) chmod +x nos scripts
# ---------------------------------------------------------------------------
chmod +x "$TARGET"/scripts/*.sh 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5) Smoke test
# ---------------------------------------------------------------------------
if [ -x "$TARGET/scripts/check.sh" ]; then
  echo "==> smoke test: scripts/check.sh --help-style exec"
  # Roda sem repo para verificar que o script nao explode
  ( cd "$HOME" && "$TARGET/scripts/check.sh" 2>&1 | head -5 ) || true
fi

echo ""
echo "==> pr-flow instalada em $TARGET"
echo "==> Proximo passo: reinicie o Claude Code para que a skill seja detectada."
echo "==> Em um repo novo, rode:"
echo "    ~/.claude/skills/pr-flow/scripts/apply.sh owner/repo"
