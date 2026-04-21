#!/usr/bin/env bash
# pr-flow: apply — instala governance em um repo (labels + branch protection
# + template + workflow).
#
# Uso: apply.sh owner/repo
#
# Requer gh CLI autenticado com permissao 'repo' e 'workflow'.

set -euo pipefail

REPO="${1:?uso: apply.sh owner/repo}"
SKILL_DIR="$HOME/.claude/skills/pr-flow"

echo "==> Verificando acesso a $REPO"
gh repo view "$REPO" >/dev/null

# ---------------------------------------------------------------------------
# 1) Labels
# ---------------------------------------------------------------------------
echo "==> Criando/atualizando labels"
python3 - "$REPO" "$SKILL_DIR/templates/labels.json" <<'PY'
import json, subprocess, sys
repo, path = sys.argv[1], sys.argv[2]
labels = json.load(open(path))
for lb in labels:
    cmd = ["gh", "label", "create", lb["name"],
           "--repo", repo,
           "--color", lb["color"],
           "--description", lb["description"],
           "--force"]
    subprocess.run(cmd, check=False)
PY

# ---------------------------------------------------------------------------
# 2) Branch protection (main + develop)
# ---------------------------------------------------------------------------
echo "==> Aplicando branch protection"
for branch in main develop; do
  exists=$(gh api "repos/$REPO/branches" --jq "[.[] | select(.name==\"$branch\")] | length" 2>/dev/null || echo 0)
  if [ "$exists" = "0" ]; then
    echo "   (branch $branch ainda nao existe — pulando)"
    continue
  fi
  gh api -X PUT "repos/$REPO/branches/$branch/protection" \
    -H "Accept: application/vnd.github+json" \
    --input "$SKILL_DIR/templates/branch-protection.json" >/dev/null \
    && echo "   $branch: protecao aplicada" \
    || echo "   $branch: falhou (verifique permissao admin)"
done

# ---------------------------------------------------------------------------
# 3) Arquivos no repo: PR template + workflow pr-limit
# ---------------------------------------------------------------------------
cat <<EOF

==> Arquivos que o repo precisa conter (via PR — nao aplicado automaticamente)

Copie os arquivos abaixo para o repo em uma branch 'chore/pr-governance':

  \$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md
    <- $SKILL_DIR/templates/PULL_REQUEST_TEMPLATE.md

  \$REPO_ROOT/.github/workflows/pr-limit.yml
    <- $SKILL_DIR/workflows/pr-limit.yml

  \$REPO_ROOT/docs/CONTRIBUTING.md
    <- $SKILL_DIR/policies/pr-policy.md

Comando rapido (dentro do repo, branch nova):
  mkdir -p .github/workflows docs
  cp $SKILL_DIR/templates/PULL_REQUEST_TEMPLATE.md .github/
  cp $SKILL_DIR/workflows/pr-limit.yml .github/workflows/
  cp $SKILL_DIR/policies/pr-policy.md docs/CONTRIBUTING.md
  git add .github docs && git commit -m "chore(governance): pr-flow templates + workflow"
EOF

# ---------------------------------------------------------------------------
# 4) Rastreio
# ---------------------------------------------------------------------------
if [ -x "$HOME/.claude/skills/orbit-engine/entrypoint.py" ]; then
  python3 "$HOME/.claude/skills/orbit-engine/entrypoint.py" \
    --action track \
    --session-id "pr-flow-apply-$(date +%Y%m%d%H%M%S)" \
    --event-type skill_activate \
    --mode auto \
    --trigger "pr-flow apply $REPO" >/dev/null 2>&1 || true
fi

echo ""
echo "PR-FLOW APPLY OK em $REPO"
