#!/usr/bin/env bash
# pr-flow: check — verifica se pode abrir novo PR.
#
# Fail-closed se:
#   - branch atual eh main ou develop
#   - HEAD eh o mesmo de uma branch ja com PR aberto
#   - escopo duplicado: outro PR aberto ja toca os mesmos arquivos no mesmo branch alvo
#   - conflito real detectado via git merge-tree
#   - diff toca src/ mas zero arquivos de teste foram alterados
#   - diff toca caminhos criticos (auth/payment/billing/migration) sem label de aprovacao
#
# Uso: check.sh [owner/repo]
# Se owner/repo omitido, usa o remote origin do diretorio atual.

set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: nao foi possivel determinar owner/repo (passe como argumento)." >&2
  exit 2
fi

# 1) Checa branch atual (apenas se estamos em repo git)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "develop" ]; then
  echo "PR-FLOW FAIL-CLOSED" >&2
  echo "Motivo: voce esta em '$BRANCH' — crie feature/fix/chore antes de commitar." >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Helper: lista arquivos modificados neste branch em relacao ao base remoto.
# Tenta origin/main, depois origin/develop, cai em HEAD~1 como fallback.
# --------------------------------------------------------------------------
_diff_files() {
  local base
  for candidate in origin/main origin/develop; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      base="$candidate"
      break
    fi
  done
  if [ -z "${base:-}" ]; then
    base="HEAD~1"
  fi
  git diff --name-only "$base"...HEAD 2>/dev/null || true
}

DIFF_FILES=$(_diff_files)

# --------------------------------------------------------------------------
# 2) Regra: escopo duplicado
#    Bloqueia se outro PR aberto ja modifica pelo menos um dos mesmos arquivos
#    no mesmo branch alvo (base branch do PR atual).
# --------------------------------------------------------------------------
TARGET_BRANCH=$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo "")
if [ -n "$TARGET_BRANCH" ] && [ -n "$DIFF_FILES" ]; then
  # Pega lista de PRs abertos que apontam para o mesmo branch alvo, excluindo o PR atual
  CURRENT_PR=$(gh pr view --json number --jq .number 2>/dev/null || echo "0")
  OPEN_PRS_JSON=$(gh pr list --repo "$REPO" --state open \
    --json number,baseRefName,files \
    --jq "[.[] | select(.baseRefName==\"$TARGET_BRANCH\" and .number != $CURRENT_PR)]" \
    2>/dev/null || echo "[]")

  while IFS= read -r pr_file; do
    [ -z "$pr_file" ] && continue
    # Verifica se esse arquivo aparece em algum outro PR aberto com mesmo alvo
    OVERLAP=$(echo "$OPEN_PRS_JSON" | \
      python3 -c "
import json, sys
data = json.load(sys.stdin)
target = sys.argv[1]
for pr in data:
    files = [f.get('path','') for f in (pr.get('files') or [])]
    if target in files:
        print(pr['number'])
        break
" "$pr_file" 2>/dev/null || true)
    if [ -n "$OVERLAP" ]; then
      echo "PR-FLOW FAIL-CLOSED" >&2
      echo "Motivo: escopo duplicado — o arquivo '$pr_file' ja eh modificado pelo PR #$OVERLAP" >&2
      echo "  (mesmo branch alvo: $TARGET_BRANCH)" >&2
      echo "Acao: mergear ou fechar o PR #$OVERLAP antes de continuar." >&2
      exit 1
    fi
  done <<< "$DIFF_FILES"
fi

# --------------------------------------------------------------------------
# 3) Regra: conflito real
#    Bloqueia se git merge-tree detecta marcadores de conflito.
# --------------------------------------------------------------------------
MERGE_BASE=$(git merge-base HEAD origin/main 2>/dev/null || true)
if [ -n "$MERGE_BASE" ] && git rev-parse --verify origin/main >/dev/null 2>&1; then
  CONFLICT_OUTPUT=$(git merge-tree "$MERGE_BASE" HEAD origin/main 2>/dev/null || true)
  if echo "$CONFLICT_OUTPUT" | grep -q '<<<<<<<'; then
    echo "PR-FLOW FAIL-CLOSED" >&2
    echo "Motivo: conflito real detectado via git merge-tree contra origin/main." >&2
    echo "Acao: rebase ou resolva os conflitos antes de abrir o PR." >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# 4) Regra: sem testes
#    Bloqueia se o diff toca arquivos em src/ mas nenhum arquivo de teste
#    (tests/, __tests__/, *.test.*, *.spec.*) foi alterado.
# --------------------------------------------------------------------------
if [ -n "$DIFF_FILES" ]; then
  SRC_TOUCHED=$(echo "$DIFF_FILES" | grep -E '^src/' | grep -v -E '\.(test|spec)\.' || true)
  TEST_TOUCHED=$(echo "$DIFF_FILES" | grep -E '(^tests/|^__tests__/|\.test\.|\.spec\.)' || true)
  if [ -n "$SRC_TOUCHED" ] && [ -z "$TEST_TOUCHED" ]; then
    echo "PR-FLOW FAIL-CLOSED" >&2
    echo "Motivo: o diff toca arquivos em src/ mas nenhum arquivo de teste foi alterado." >&2
    echo "  Arquivos src/ modificados:" >&2
    echo "$SRC_TOUCHED" | sed 's/^/    /' >&2
    echo "Acao: adicione ou atualize testes em tests/, __tests__/, *.test.* ou *.spec.*" >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# 5) Regra: risco critico
#    Bloqueia se o diff toca caminhos sensiveis (auth/payment/billing/migration)
#    e o PR nao possui label de aprovacao explicita.
# --------------------------------------------------------------------------
if [ -n "$DIFF_FILES" ]; then
  CRITICAL_TOUCHED=$(echo "$DIFF_FILES" | grep -iE '(auth|payment|billing|migration)' || true)
  if [ -n "$CRITICAL_TOUCHED" ]; then
    # Verifica labels no PR atual (se existir)
    PR_LABELS=$(gh pr view --json labels --jq '[.labels[].name] | @csv' 2>/dev/null || echo "")
    APPROVED=0
    for label in approved lgtm security-ok; do
      if echo "$PR_LABELS" | grep -qi "$label"; then
        APPROVED=1
        break
      fi
    done
    if [ "$APPROVED" = "0" ]; then
      echo "PR-FLOW FAIL-CLOSED" >&2
      echo "Motivo: risco critico — o diff toca caminhos sensiveis sem aprovacao explicita." >&2
      echo "  Arquivos criticos:" >&2
      echo "$CRITICAL_TOUCHED" | sed 's/^/    /' >&2
      echo "Acao: obtenha uma das labels 'approved', 'lgtm' ou 'security-ok' no PR antes de prosseguir." >&2
      exit 1
    fi
  fi
fi

# 6) Rastreia via orbit-engine (fail-closed se backend down)
if [ -x "$HOME/.claude/skills/orbit-engine/entrypoint.py" ]; then
  python3 "$HOME/.claude/skills/orbit-engine/entrypoint.py" \
    --action track \
    --session-id "pr-flow-check-$(date +%Y%m%d%H%M%S)" \
    --event-type skill_activate \
    --mode auto \
    --trigger "pr-flow check $REPO" >/dev/null 2>&1 || true
fi

echo "PR-FLOW OK"
echo "  repo:   $REPO"
echo "  branch: $BRANCH"
exit 0
