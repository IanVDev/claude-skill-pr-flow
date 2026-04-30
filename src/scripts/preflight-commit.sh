#!/usr/bin/env bash
# pr-flow: preflight-commit — checklist pre-commit.
#
# Uso: preflight-commit.sh
#
# Fail-closed:
#   - branch atual eh main, develop ou master (commit direto proibido)
#   - escopo duplicado: outro PR aberto modifica os mesmos arquivos staged no
#     mesmo branch alvo
#   - conflito real: git merge-tree detecta marcadores de conflito
#   - sem testes: staged toca src/ mas zero arquivos de teste foram staged
#   - risco critico: staged toca auth/payment/billing/migration sem label de aprovacao
#
# OK:
#   - branch atual inicia com feature/, fix/, chore/, hotfix/, docs/
#   - nenhuma das regras acima disparada

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
while IFS= read -r f; do [ -n "$f" ] && echo "    $f"; done <<< "$STAGED"
if [ -n "$UNSTAGED" ]; then
  echo "  AVISO — arquivos modificados nao staged:"
  while IFS= read -r f; do [ -n "$f" ] && echo "    $f"; done <<< "$UNSTAGED"
fi

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)

# --------------------------------------------------------------------------
# Regra 1: escopo duplicado
#    Bloqueia se outro PR aberto ja modifica pelo menos um dos arquivos staged
#    no mesmo branch alvo.
# --------------------------------------------------------------------------
if [ -n "$REPO" ] && [ -n "$STAGED" ]; then
  TARGET_BRANCH=$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo "")
  CURRENT_PR=$(gh pr view --json number --jq .number 2>/dev/null || echo "0")

  if [ -n "$TARGET_BRANCH" ]; then
    OPEN_PRS_JSON=$(gh pr list --repo "$REPO" --state open \
      --json number,baseRefName,files \
      --jq "[.[] | select(.baseRefName==\"$TARGET_BRANCH\" and .number != $CURRENT_PR)]" \
      2>/dev/null || echo "[]")

    while IFS= read -r staged_file; do
      [ -z "$staged_file" ] && continue
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
" "$staged_file" 2>/dev/null || true)
      if [ -n "$OVERLAP" ]; then
        echo "PR-FLOW FAIL-CLOSED" >&2
        echo "Motivo: escopo duplicado — '$staged_file' ja modificado pelo PR #$OVERLAP" >&2
        echo "  (mesmo branch alvo: $TARGET_BRANCH)" >&2
        echo "Acao: mergear ou fechar PR #$OVERLAP antes de commitar." >&2
        exit 1
      fi
    done <<< "$STAGED"
  fi
fi

# --------------------------------------------------------------------------
# Regra 2: conflito real
#    Bloqueia se git merge-tree detecta marcadores de conflito contra origin/main.
# --------------------------------------------------------------------------
MERGE_BASE=$(git merge-base HEAD origin/main 2>/dev/null || true)
if [ -n "$MERGE_BASE" ] && git rev-parse --verify origin/main >/dev/null 2>&1; then
  CONFLICT_OUTPUT=$(git merge-tree "$MERGE_BASE" HEAD origin/main 2>/dev/null || true)
  if echo "$CONFLICT_OUTPUT" | grep -q '<<<<<<<'; then
    echo "PR-FLOW FAIL-CLOSED" >&2
    echo "Motivo: conflito real detectado via git merge-tree contra origin/main." >&2
    echo "Acao: rebase ou resolva os conflitos antes de commitar." >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# Regra 3: sem testes
#    Bloqueia se staged toca src/ (exceto *.test.*/spec.*) mas nenhum
#    arquivo de teste esta staged.
# --------------------------------------------------------------------------
if [ -n "$STAGED" ]; then
  SRC_STAGED=$(echo "$STAGED" | grep -E '^src/' | grep -v -E '\.(test|spec)\.' || true)
  TEST_STAGED=$(echo "$STAGED" | grep -E '(^tests/|^__tests__/|\.test\.|\.spec\.)' || true)
  if [ -n "$SRC_STAGED" ] && [ -z "$TEST_STAGED" ]; then
    echo "PR-FLOW FAIL-CLOSED" >&2
    echo "Motivo: staged toca src/ mas nenhum arquivo de teste esta staged." >&2
    echo "  Arquivos src/ staged:" >&2
    echo "$SRC_STAGED" | sed 's/^/    /' >&2
    echo "Acao: adicione ou atualize testes em tests/, __tests__/, *.test.* ou *.spec.*" >&2
    exit 1
  fi
fi

# --------------------------------------------------------------------------
# Regra 4: risco critico
#    Bloqueia se staged toca auth/payment/billing/migration e o PR nao tem
#    label de aprovacao explicita.
# --------------------------------------------------------------------------
if [ -n "$STAGED" ]; then
  CRITICAL_STAGED=$(echo "$STAGED" | grep -iE '(auth|payment|billing|migration)' || true)
  if [ -n "$CRITICAL_STAGED" ]; then
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
      echo "Motivo: risco critico — staged toca caminhos sensiveis sem aprovacao explicita." >&2
      echo "  Arquivos criticos staged:" >&2
      echo "$CRITICAL_STAGED" | sed 's/^/    /' >&2
      echo "Acao: obtenha label 'approved', 'lgtm' ou 'security-ok' no PR antes de commitar." >&2
      exit 1
    fi
  fi
fi

exit 0
