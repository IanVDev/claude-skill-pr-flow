# pr-flow

Claude Code skill para governança de Pull Requests. Impõe disciplina de fluxo contínuo em vez de burocracia de revisão.

> **Fail-closed por design.** Violação de regra bloqueia a operação com diagnóstico claro. Nada passa silenciosamente.

## O que a skill resolve

Cenário real que motivou a criação: 5 PRs abertos simultaneamente em um repo, nenhuma label, CI opcional, dev commita em `develop` por engano. Tempo de revisão infla, conflitos de merge aparecem, releases travam.

A `pr-flow` impõe:

| Regra | Como |
|---|---|
| Máx **2 PRs abertos** por repo | Workflow `pr-limit.yml` comenta + falha o check no 3º PR |
| **CI verde obrigatório** antes do merge | Branch protection em `main` e `develop` |
| **1 review aprovada** mínima | Branch protection |
| **Labels padronizadas** (`ready-to-merge`, `blocked`, `needs-review`) | Criadas via `gh label create --force` |
| **Squash merge** | Histórico linear |
| Preflight **anti commit em branch errada** | `preflight-commit.sh` fail-close em `main`/`develop` |

## Instalação rápida

```bash
# baixa o release mais recente e extrai direto:
curl -sSL https://github.com/IanVDev/claude-skill-pr-flow/releases/latest/download/pr-flow.skill \
  | tar -xz -C ~/.claude/skills/

# OU instalação validada por checksum:
mkdir -p /tmp/pr-flow && cd /tmp/pr-flow
curl -sSLO https://github.com/IanVDev/claude-skill-pr-flow/releases/latest/download/pr-flow.skill
curl -sSLO https://github.com/IanVDev/claude-skill-pr-flow/releases/latest/download/manifest.json
curl -sSLO https://github.com/IanVDev/claude-skill-pr-flow/releases/latest/download/install.sh
chmod +x install.sh && ./install.sh
```

Reinicie o Claude Code para a skill ser detectada.

## Uso

### Em um repo novo (aplicar governança)
```bash
~/.claude/skills/pr-flow/scripts/apply.sh owner/repo
```
Cria 3 labels, aplica branch protection em `main` e `develop`, imprime próximos passos para copiar o template de PR e o workflow.

### Antes de abrir novo PR
```bash
~/.claude/skills/pr-flow/scripts/check.sh
# PR-FLOW OK               → pode abrir
# PR-FLOW FAIL-CLOSED      → drene a fila antes
```

### Antes de qualquer `git commit`
```bash
~/.claude/skills/pr-flow/scripts/preflight-commit.sh
# fail-close em main/develop, avisa conflitos com PRs ativos
```

## Estrutura do repo

```
├── src/                           # código-fonte da skill (editável)
│   ├── skill.md                   # entrypoint detectado pelo Claude Code
│   ├── skill.yaml                 # metadata + limites + fail_closed
│   ├── policies/                  # políticas de PR e merge (texto p/ equipe)
│   ├── templates/                 # PULL_REQUEST_TEMPLATE, labels, branch-protection
│   ├── workflows/                 # pr-limit.yml (copiado p/ repo gerenciado)
│   └── scripts/                   # check.sh, apply.sh, preflight-commit.sh
├── dist/                          # artefato de release (regenerado em tag)
│   ├── pr-flow.skill              # tarball gzip auto-contido
│   ├── manifest.json              # metadata + checksum sha256
│   ├── install.sh                 # instalador com validação de checksum
│   ├── uninstall.sh
│   └── INSTALL.md
└── .github/workflows/ci.yml       # shellcheck + verificação de checksum em PR
```

## Política escrita

Ver [src/policies/pr-policy.md](src/policies/pr-policy.md) e [src/policies/merge-policy.md](src/policies/merge-policy.md).

## Como contribuir

1. `~/.claude/skills/pr-flow/scripts/check.sh IanVDev/claude-skill-pr-flow` — fail-close se já há 2 PRs abertos.
2. Branch `feature/`, `fix/`, `chore/`, `hotfix/` ou `docs/`.
3. Edite `src/`. Se o comportamento da skill mudou, regenere `dist/pr-flow.skill` localmente antes do commit (ver abaixo).
4. PR para `main` com body seguindo o template.

### Regenerar `dist/pr-flow.skill` localmente

```bash
cd src && tar czf ../dist/pr-flow.skill --transform 's|^|pr-flow/|' \
  skill.md skill.yaml policies templates workflows scripts
# atualize manifest.json com novo sha:
SHA=$(shasum -a 256 ../dist/pr-flow.skill | awk '{print $1}')
python3 -c "import json; m=json.load(open('../dist/manifest.json')); m['artifact_sha256']='$SHA'; json.dump(m, open('../dist/manifest.json','w'), indent=2)"
```

CI (`ci.yml`) valida que o `artifact_sha256` do `manifest.json` bate com o tarball commitado — se esquecer de atualizar, o check falha.

## Release

Release é **manual** (não automatizado) — mantém visibilidade de quem publicou o quê:

```bash
# 1. bump de versão em src/skill.yaml e dist/manifest.json
# 2. regenere dist/ (ver acima) e commit
# 3. tag + push
git tag v1.0.1 && git push --tags
# 4. criar release com assets:
gh release create v1.0.1 \
  dist/pr-flow.skill \
  dist/manifest.json \
  dist/install.sh \
  dist/INSTALL.md \
  --title "pr-flow v1.0.1" \
  --notes "<changelog>"
```

## Licença

MIT. Ver [LICENSE](LICENSE).

## Observabilidade (opcional)

Os scripts rastreiam execução via [orbit-engine](https://github.com/IanVDev/orbit-engine) se estiver rodando em `localhost:9100`. Sem ele, os scripts funcionam normalmente (rastreio silencioso, sem falhas).
