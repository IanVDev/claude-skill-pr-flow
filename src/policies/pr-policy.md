# Politica de Pull Requests

## Principio

PRs nao sao sessoes de revisao eterna. Sao **pulsos curtos** que entram
rapido quando o CI valida. Fluxo continuo > burocracia.

## Regras de bloqueio (fail-closed)

As regras abaixo bloqueiam a operacao com exit code != 0. Sao verificadas
por `check.sh` (antes de abrir PR) e `preflight-commit.sh` (antes de commitar).

### 1. Sem escopo duplicado

- Bloqueio se outro PR aberto ja modifica pelo menos um dos mesmos arquivos
  e aponta para o mesmo branch alvo.
- Definicao: mesmo `baseRefName` E pelo menos um caminho de arquivo em comum
  no diff do PR atual e de um PR ainda aberto.
- Acao: mergear ou fechar o PR sobreponente antes de continuar.

### 2. Sem conflito real

- Bloqueio se `git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main`
  produz marcadores de conflito (`<<<<<<<`).
- Acao: fazer rebase sobre `origin/main` e resolver conflitos antes de abrir PR.

### 3. Testes obrigatorios

- Bloqueio se o diff toca arquivos em `src/` (logica) mas zero arquivos de
  teste (`tests/`, `__tests__/`, `*.test.*`, `*.spec.*`) foram alterados.
- Acao: adicionar ou atualizar testes cobrindo as mudancas em `src/`.

### 4. Aprovacao explicita para caminhos criticos

- Bloqueio se o diff toca qualquer arquivo cujo caminho contenha `auth`,
  `payment`, `billing` ou `migration` e o PR nao possui label `approved`,
  `lgtm` ou `security-ok`.
- Acao: obter revisao explicita e aplicar uma das labels antes de prosseguir.

## Demais regras

### 5. Small PR first

- PR pequeno (< 200 linhas alteradas) tem precedencia na fila de review.
- PR grande (> 500 linhas) deve ser quebrado em PRs menores, exceto em
  mudancas atomicas (ex: migracao de arquivo).

### 6. CI verde obrigatorio

- Sem os checks `tests` e `smoke-build` verdes, nao eh mergeavel.
- Branch protection forca o bloqueio — nao ha como burlar.

### 7. 1 review aprovada minima

- PR de autor != reviewer.
- Em equipe pequena (< 3 devs), admin pode auto-aprovar apos 24h sem review.

### 8. Merge por squash

- Historico linear em `develop` e `main`.
- Commit da squash usa o titulo do PR como mensagem principal.

### 9. Labels

- `ready-to-merge`: CI verde + review aprovada. Qualquer mantenedor pode
  mergear.
- `blocked`: aguardando dependencia externa (rotacao de secret,
  endpoint backend, etc). NAO mergear.
- `needs-review`: precisa de olhar humano. Aberto mas nao urgente.

### 10. Prazo de vida de um PR

- **< 48h**: ideal. Small PRs devem mergear no mesmo dia de CI verde.
- **> 7 dias**: stale. O autor deve fechar ou justificar no body.
- **> 14 dias**: auto-close pelo workflow (configuravel).

## Violacoes

A skill bloqueia as quatro violacoes substantivas listadas acima (escopo
duplicado, conflito real, sem testes, risco critico sem aprovacao) alem de
branch errada, CI ausente, branch protection ausente e estado git inseguro.
