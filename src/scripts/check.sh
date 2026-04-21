#!/usr/bin/env bash
# pr-flow: check — verifica se pode abrir novo PR.
#
# Fail-closed se:
#   - ja ha >= 2 PRs abertos no repo
#   - branch atual eh main ou develop
#   - HEAD eh o mesmo de uma branch ja com PR aberto
#
# Uso: check.sh [owner/repo]
# Se owner/repo omitido, usa o remote origin do diretorio atual.

set -euo pipefail

MAX_OPEN=2
REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: nao foi possivel determinar owner/repo (passe como argumento)." >&2
  exit 2
fi

# 1) Conta PRs abertos
OPEN=$(gh pr list --repo "$REPO" --state open --json number --jq 'length')
if [ "$OPEN" -ge "$MAX_OPEN" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: $OPEN PRs abertos em $REPO (limite: $MAX_OPEN)." >&2
  echo "Acao: merge ou close um PR existente antes de abrir outro." >&2
  exit 1
fi

# 2) Checa branch atual (apenas se estamos em repo git)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "develop" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: voce esta em '$BRANCH' — crie feature/fix/chore antes de commitar." >&2
  exit 1
fi

# 3) Rastreia via orbit-engine (fail-closed se backend down)
if [ -x "$HOME/.claude/skills/orbit-engine/entrypoint.py" ]; then
  python3 "$HOME/.claude/skills/orbit-engine/entrypoint.py" \
    --action track \
    --session-id "pr-flow-check-$(date +%Y%m%d%H%M%S)" \
    --event-type skill_activate \
    --mode auto \
    --trigger "pr-flow check $REPO" >/dev/null 2>&1 || true
fi

echo "PR-FLOW OK"
echo "  repo: $REPO"
echo "  branch: $BRANCH"
echo "  open_prs: $OPEN / $MAX_OPEN"
exit 0
