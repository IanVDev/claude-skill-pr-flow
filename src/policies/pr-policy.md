# Politica de Pull Requests

## Principio

PRs nao sao sessoes de revisao eterna. Sao **pulsos curtos** que entram
rapido quando o CI valida. Fluxo continuo > burocracia.

## Regras

### 1. Maximo 2 PRs abertos simultaneos por desenvolvedor por repo

- Antes de abrir um terceiro, merge/close um existente.
- Hotfix de producao autorizado pelo tech lead pode estourar — registre o
  motivo no body do PR.

### 2. Small PR first

- PR pequeno (< 200 linhas alteradas) tem precedencia na fila de review.
- PR grande (> 500 linhas) deve ser quebrado em PRs menores, exceto em
  mudancas atomicas (ex: migracao de arquivo).

### 3. CI verde obrigatorio

- Sem os checks `tests` e `smoke-build` verdes, nao eh mergeavel.
- Branch protection forca o bloqueio — nao ha como burlar.

### 4. 1 review aprovada minima

- PR de autor != reviewer.
- Em equipe pequena (< 3 devs), admin pode auto-aprovar apos 24h sem review.

### 5. Merge por squash

- Historico linear em `develop` e `main`.
- Commit da squash usa o titulo do PR como mensagem principal.

### 6. Labels

- `ready-to-merge`: CI verde + review aprovada. Qualquer mantenedor pode
  mergear.
- `blocked`: aguardando dependencia externa (rotacao de secret,
  endpoint backend, etc). NAO mergear.
- `needs-review`: precisa de olhar humano. Aberto mas nao urgente.

### 7. Prazo de vida de um PR

- **< 48h**: ideal. Small PRs devem mergear no mesmo dia de CI verde.
- **> 7 dias**: stale. O autor deve fechar ou justificar no body.
- **> 14 dias**: auto-close pelo workflow (configuravel).

## Violacoes

O workflow `pr-limit.yml` comenta nos PRs quando o limite eh estourado e
falha o check. Ate o limite normalizar, nao se mergea nada novo.

## Exemplo pratico

Cenario real observado (20/04/2026):
- 5 PRs abertos simultaneos — violacao da regra 1.
- Nenhuma label aplicada — nao da para priorizar.
- CI nao configurado como obrigatorio — risco de merge quebrado.

Correcao aplicada:
1. Merge sequencial: PR #1 (bootstrap) → habilita CI para os demais.
2. PR #2 e #3 (seguranca) drenam juntos pois independentes.
3. PR #4 entra apos #2.
4. PR #5 entra por ultimo.

A partir desse ponto, regra de 2 ja valia — PR #6 (governance) entra
como unico aberto.
