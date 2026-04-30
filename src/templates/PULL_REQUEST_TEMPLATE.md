## Objetivo
<!-- O que este PR resolve, em 1-2 linhas. Cite o trilho/task do roadmap. -->

## Escopo
<!-- Lista de arquivos alterados com finalidade. -->

## Fora de escopo
<!-- O que explicitamente NAO entra neste PR (evita scope creep). -->

## Teste anti-regressao
<!-- Caminho do arquivo de teste + 1 linha do que ele valida. -->

## Como validar localmente
```bash
# comandos
```

## Dependencias
<!-- Outros PRs que precisam mergear antes. -->

## Rollback
<!-- Como reverter caso de regressao em producao. -->

## Observabilidade (orbit-engine)
<!-- Sessao e event_id, se aplicavel. -->

---
**Checklist do autor:**
- [ ] Menos de 200 linhas OU escopo atomico justificado
- [ ] Nenhum outro PR aberto toca os mesmos arquivos no mesmo branch alvo (sem escopo duplicado)
- [ ] `git merge-tree` sem marcadores de conflito contra `origin/main`
- [ ] Se diff toca `src/`, ha pelo menos um arquivo de teste (`tests/`, `*.test.*`, `*.spec.*`) staged
- [ ] Se diff toca `auth`/`payment`/`billing`/`migration`, label `approved`, `lgtm` ou `security-ok` aplicada
- [ ] Body contem secao Rollback
- [ ] Nao mistura escopos (1 PR = 1 proposito)
- [ ] Nao alterei arquitetura sem necessidade
