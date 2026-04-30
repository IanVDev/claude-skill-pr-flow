---
name: pr-flow
description: >
  Governance de Pull Requests: CI obrigatório, labels padronizadas, branch
  protection, preflight git-state e quatro regras de bloqueio substantivas.
  Use esta skill sempre que o usuário mencionar abrir PR, fazer commit,
  mergear branch, criar PR, revisar PR, branch protection, labels de PR,
  fluxo de PR, "posso commitar", "vou abrir um PR", "quero mergear",
  "tem PR aberto", "branch errada", ou qualquer situação de governança de
  código em repositório Git/GitHub. Dispare também quando houver risco de
  commit em branch protegida. Fail-closed em violações de governança.
---

# pr-flow Skill

Governanca de PRs para manter fluxo continuo e evitar riscos reais. Integra com
`gh` CLI e GitHub Actions. Fail-closed em violacoes de governanca real.

## Principios

1. **Escopo unico por PR.** Bloqueio se outro PR aberto ja modifica arquivos
   sobrepostos no mesmo branch alvo (regra de escopo duplicado).
2. **Sem conflitos reais.** Bloqueio se `git merge-tree` detecta marcadores
   de conflito (`<<<<<<<`) contra `origin/main`.
3. **Testes obrigatorios.** Se o diff toca `src/`, pelo menos um arquivo de
   teste (`tests/`, `__tests__/`, `*.test.*`, `*.spec.*`) deve ser alterado.
4. **Aprovacao explicita para caminhos criticos.** Diff que toca
   `auth`, `payment`, `billing` ou `migration` requer label `approved`,
   `lgtm` ou `security-ok` no PR.
5. **CI verde obrigatorio.** Sem o check `tests` passando, nao mergear.
6. **Fail-closed em git state.** Antes de qualquer `git commit`, validar que
   a branch atual nao eh `develop`/`main` nem branch de outro PR em progresso.
7. **Labels disciplinadas.** `ready-to-merge`, `blocked`, `needs-review`.

## Acoes

### check
Verifica o estado atual antes de abrir novo PR. Aplica as quatro regras de
bloqueio. Retorna OK apenas se todas as regras passarem.

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
Checklist executado antes de um commit ser feito — aplica as quatro regras de
bloqueio nos arquivos staged:

```bash
~/.claude/skills/pr-flow/scripts/preflight-commit.sh
```

Imprime:
- branch atual
- ultimo commit
- arquivos staged
- resultado de cada regra de bloqueio

Exit code != 0 se detectar violacao em qualquer uma das quatro regras ou
commit iminente em `develop`/`main`.

### team-message
Gera mensagem estruturada para comunicar o PR ao time, usando o template em
`templates/team-pr-message-template.md`. A mensagem inclui: resumo das
mudancas, ponto mais importante, validacoes, riscos residuais, condicao de
merge/deploy e declaracao de fora de escopo.

Template: `~/.claude/skills/pr-flow/templates/team-pr-message-template.md`

## Quando usar

- **Antes de abrir um novo PR:** `check` aplica as quatro regras de bloqueio
  e verifica se a branch eh correta.
- **Em novo repo:** `apply` instala todas as guardas.
- **Antes de qualquer commit em sessao com multiplos PRs em progresso:**
  `preflight-commit` confirma que estou na branch certa e valida as regras.
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
Motivo: <descricao da regra violada>
Acao:   <o que fazer para resolver>
```

As quatro regras de bloqueio substantivas sao:

1. **Escopo duplicado** — outro PR aberto ja modifica os mesmos arquivos no
   mesmo branch alvo. Mergear ou fechar o PR conflitante antes.
2. **Conflito real** — `git merge-tree` encontrou `<<<<<<<`. Fazer rebase ou
   resolver conflitos.
3. **Sem testes** — diff toca `src/` mas nenhum arquivo de teste foi alterado.
   Adicionar testes.
4. **Risco critico sem aprovacao** — diff toca `auth`/`payment`/`billing`/
   `migration` sem label `approved`, `lgtm` ou `security-ok`. Obter aprovacao.
