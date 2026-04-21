---
name: pr-flow
description: >
  Governance skill para fluxo de Pull Requests. Impoe: maximo 2 PRs abertos
  simultaneos, CI verde obrigatorio antes do merge, labels padronizadas,
  branch protection e checagem de git-state antes de commit (evita commit em
  branch errada). Fail-closed em violacao de limite.
---

# pr-flow Skill

Governanca de PRs para manter fluxo continuo e evitar acumulo. Integra com
`gh` CLI e GitHub Actions. Fail-closed em violacoes de limite.

## Principios

1. **Maximo 2 PRs abertos por repo.** Um terceiro so pode ser aberto apos
   merge/close de outro. Workflow `pr-limit.yml` publica um comment no 3o+ PR
   e falha o check.
2. **Small PR first.** Se houver PRs pequenos (< 200 linhas) com CI verde,
   mergear antes de abrir novo.
3. **CI verde obrigatorio.** Sem o check `tests` passando, nao mergear.
4. **Fail-closed em git state.** Antes de qualquer `git commit`, validar que
   a branch atual nao eh `develop`/`main` nem branch de outro PR em progresso.
5. **Labels disciplinadas.** `ready-to-merge`, `blocked`, `needs-review`.

## Acoes

### check
Verifica o estado atual antes de abrir novo PR. Retorna OK se:
- < 2 PRs abertos no repo
- branch atual eh feature/fix/chore e nao eh branch de outro PR

```bash
~/.claude/skills/pr-flow/scripts/check.sh [--repo owner/name]
```

Exit code != 0 = fail-closed (nao prosseguir com novo PR).

### apply
Aplica labels, branch protection e template de PR em um repo novo:

```bash
~/.claude/skills/pr-flow/scripts/apply.sh owner/name
```

Acoes executadas:
- `gh label create` para as 3 labels padrao
- `gh api` para branch protection em `main` e `develop` (exige CI + reviews)
- copia `templates/PULL_REQUEST_TEMPLATE.md` para `.github/` do repo
- copia `workflows/pr-limit.yml` para `.github/workflows/` do repo

### preflight-commit
Checklist executado antes de um commit ser feito — evita o erro classico de
commitar na branch errada:

```bash
~/.claude/skills/pr-flow/scripts/preflight-commit.sh
```

Imprime:
- branch atual
- ultimo commit
- arquivos staged
- branch esperada pelo contexto (se deriva de pattern chore/fix/feature)

Exit code != 0 se detectar commit iminente em `develop`/`main`.

## Quando usar

- **Antes de abrir um novo PR:** `check` fail-closed se ja tem 2 abertos.
- **Em novo repo:** `apply` instala todas as guardas.
- **Antes de qualquer commit em sessao com multiplos PRs em progresso:**
  `preflight-commit` confirma que estou na branch certa.

## Quando NAO usar

- PRs de hotfix de producao autorizados explicitamente pelo usuario (podem
  estourar o limite de 2; registre decisao no PR body).
- Repos sem CI configurado (primeiro instale CI, depois `apply`).

## Rastreabilidade

Toda execucao chama `orbit-engine track` automaticamente (ver `scripts/*`).
Fail-closed se backend orbit-engine nao responder.

## Estrutura de arquivos

```
~/.claude/skills/pr-flow/
├── SKILL.md                          # entrypoint detectado pelo Claude Code
├── skill.yaml                        # metadata estruturado
├── policies/
│   ├── pr-policy.md                  # politica para a equipe
│   └── merge-policy.md               # criterios de merge
├── templates/
│   ├── PULL_REQUEST_TEMPLATE.md      # template de PR
│   ├── labels.json                   # labels padrao
│   └── branch-protection.json        # payload da API para protection
├── workflows/
│   └── pr-limit.yml                  # Action que alerta > 2 PRs abertos
└── scripts/
    ├── check.sh                      # verifica estado antes de novo PR
    ├── apply.sh                      # aplica governance em um repo
    └── preflight-commit.sh           # checklist pre-commit (git state)
```

## Protocolo fail-closed

Em caso de violacao, pare com a mensagem:

```
PR-FLOW FAIL-CLOSED
Motivo: <limite excedido | branch errada | CI nao verde>
Acao: <aguardar merge | trocar branch | aguardar CI>
```
