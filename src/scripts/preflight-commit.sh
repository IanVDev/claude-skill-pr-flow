#!/usr/bin/env bash
# pr-flow: preflight-commit — checklist pre-commit.
#
# Uso: preflight-commit.sh
#
# Fail-closed:
#   - branch atual eh main ou develop (commit direto proibido)
#   - HEAD tem staged changes que conflitam com PR ja aberto na mesma branch
#
# OK:
#   - branch atual inicia com feature/, fix/, chore/, hotfix/, docs/
#   - nenhum PR aberto referencia outra branch com os mesmos arquivos staged

set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$BRANCH" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: diretorio atual nao eh um repo git." >&2
  exit 2
fi

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "master" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: voce esta em '$BRANCH'. Nao commitar direto em ramo protegido." >&2
  echo "Acao: git checkout -b feature/<nome>  OU  git checkout -b fix/<nome>" >&2
  exit 1
fi

case "$BRANCH" in
  feature/*|fix/*|chore/*|hotfix/*|docs/*) : ;;
  *)
    echo "PR-FLOW WARN" >&2
    echo "Aviso: branch '$BRANCH' nao segue convencao (feature/|fix/|chore/|hotfix/|docs/)." >&2
    echo "Acao sugerida: renomear com 'git branch -m <novo-nome>'." >&2
    ;;
esac

STAGED=$(git diff --cached --name-only)
UNSTAGED=$(git diff --name-only)

echo "PR-FLOW preflight-commit"
echo "  branch atual:   $BRANCH"
echo "  ultimo commit:  $(git log -1 --pretty=oneline --abbrev-commit)"
echo "  staged files:"
echo "$STAGED" | sed 's/^/    /'
if [ -n "$UNSTAGED" ]; then
  echo "  AVISO — arquivos modificados nao staged:"
  echo "$UNSTAGED" | sed 's/^/    /'
fi

# Cruzamento com PRs abertos — alerta se um PR ativo usa branch que contem
# algum dos arquivos staged.
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
if [ -n "$REPO" ] && [ -n "$STAGED" ]; then
  OPEN_BRANCHES=$(gh pr list --repo "$REPO" --state open --json headRefName --jq '.[].headRefName' 2>/dev/null || true)
  for b in $OPEN_BRANCHES; do
    if [ "$b" != "$BRANCH" ]; then
      for f in $STAGED; do
        if git log "origin/$b" -- "$f" -n 1 --pretty=format:'' 2>/dev/null | grep -q .; then
          echo "  AVISO: $f tambem foi tocado por PR aberto em '$b'. Risco de conflito." >&2
        fi
      done
    fi
  done
fi

exit 0
