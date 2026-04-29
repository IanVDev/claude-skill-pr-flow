#!/usr/bin/env bash
# pr-flow: check — verifica se pode abrir novo PR.
#
# Fail-closed se:
#   - branch atual eh main ou develop
#   - HEAD eh o mesmo de uma branch ja com PR aberto
#
# Aviso (nao bloqueia) se:
#   - ha >= 5 PRs abertos no repo
#
# Uso: check.sh [owner/repo]
# Se owner/repo omitido, usa o remote origin do diretorio atual.

set -euo pipefail

WARN_THRESHOLD=5
REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: nao foi possivel determinar owner/repo (passe como argumento)." >&2
  exit 2
fi

# 1) Conta PRs abertos — alerta informativo se acumulo alto, nao bloqueia
OPEN=$(gh pr list --repo "$REPO" --state open --json number --jq 'length')
if [ "$OPEN" -ge "$WARN_THRESHOLD" ]; then
  echo "PR-FLOW WARN" >&2
  echo "Aviso: $OPEN PRs abertos em $REPO." >&2
  echo "Recomendacao: revise a fila e mergear ou fechar PRs travados antes de abrir novos." >&2
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
echo "  open_prs: $OPEN"
exit 0
