---
name: pr-flow
description: >
  Governance skill para fluxo de Pull Requests. Impoe: CI verde obrigatorio
  antes do merge, labels padronizadas, branch protection e checagem de
  git-state antes de commit (evita commit em branch errada). Alerta sobre
  acumulo de PRs. Fail-closed em violacoes de governanca real.
---

# pr-flow Skill

Governanca de PRs para manter fluxo continuo e evitar acumulo. Integra com
`gh` CLI e GitHub Actions. Fail-closed em violacoes de governanca real.

## Principios

1. **Sem limite fixo de PRs.** A skill alerta quando ha 5 ou mais PRs
   abertos simultaneamente, mas nao bloqueia por quantidade. Bloqueio
   reservado para riscos reais de governanca.
2. **Small PR first.** Se houver PRs pequenos (< 200 linhas) com CI verde,
   mergear antes de abrir novo.
3. **CI verde obrigatorio.** Sem o check `tests` passando, nao mergear.
4. **Fail-closed em git state.** Antes de qualquer `git commit`, validar que
   a branch atual nao eh `develop`/`main` nem branch de outro PR em progresso.
5. **Labels disciplinadas.** `ready-to-merge`, `blocked`, `needs-review`.

## Acoes

### check
Verifica o estado atual antes de abrir novo PR. Retorna OK se:
- branch atual eh feature/fix/chore e nao eh branch de outro PR
- alerta (nao bloqueia) se ha 5 ou mais PRs abertos

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

### team-message
Gera mensagem estruturada para comunicar o PR ao time, usando o template em
`templates/team-pr-message-template.md`. A mensagem inclui: resumo das
mudancas, ponto mais importante, validacoes, riscos residuais, condicao de
merge/deploy e declaracao de fora de escopo.

Template: `~/.claude/skills/pr-flow/templates/team-pr-message-template.md`

## Quando usar

- **Antes de abrir um novo PR:** `check` alerta se ha acumulo de PRs, bloqueia
  se a branch for errada.
- **Em novo repo:** `apply` instala todas as guardas.
- **Antes de qualquer commit em sessao com multiplos PRs em progresso:**
  `preflight-commit` confirma que estou na branch certa.
- **Apos abrir ou finalizar um PR:** use o `team-message` template para
  comunicar o time de forma padronizada.

## Quando NAO usar

- Repos sem CI configurado (primeiro instale CI, depois `apply`).

## Rastreabilidade

Toda execucao chama `orbit-engine track` automaticamente (ver `scripts/*`).
Fail-closed se backend orbit-engine nao responder.

## Estrutura de arquivos

```
~/.claude/skills/pr-flow/
├── SKILL.md                              # entrypoint detectado pelo Claude Code
├── skill.yaml                            # metadata estruturado
├── policies/
│   ├── pr-policy.md                      # politica para a equipe
│   └── merge-policy.md                   # criterios de merge
├── templates/
│   ├── PULL_REQUEST_TEMPLATE.md          # template de PR
│   ├── team-pr-message-template.md       # template de mensagem para o time
│   ├── labels.json                       # labels padrao
│   └── branch-protection.json            # payload da API para protection
└── scripts/
    ├── check.sh                          # verifica estado antes de novo PR
    ├── apply.sh                          # aplica governance em um repo
    └── preflight-commit.sh               # checklist pre-commit (git state)
```

## Protocolo fail-closed

Em caso de violacao, pare com a mensagem:

```
PR-FLOW FAIL-CLOSED
Motivo: <branch errada | CI nao verde | branch protection ausente>
Acao: <trocar branch | aguardar CI | configurar protection>
```

Acumulo de PRs gera apenas:

```
PR-FLOW WARN
Aviso: N PRs abertos em owner/repo.
Recomendacao: revise a fila antes de abrir novos.
```
