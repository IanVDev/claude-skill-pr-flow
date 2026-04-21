# Criterios de Merge

## Checklist obrigatorio

Antes de apertar "Merge":

- [ ] Branch de PR nao eh `main` nem `develop`.
- [ ] Check `tests` verde.
- [ ] Check `smoke-build` verde (se aplicavel).
- [ ] Pelo menos 1 review aprovada (ou auto-aprovacao com motivo em equipe pequena).
- [ ] Nenhuma conversa aberta sem resposta.
- [ ] Label `ready-to-merge` aplicada.
- [ ] PR nao tem label `blocked`.
- [ ] Body do PR tem secao "Rollback" (como reverter em prod).
- [ ] Mudanca de secret/env/permissao: confirmar rotacao/deploy coordenado.

## Ordem de merge quando ha multiplos PRs verdes

1. **Hotfix de producao** (sempre primeiro).
2. **Bloqueios de CI/infra** (ex: adicionar workflow, scripts, gitignore).
3. **Seguranca** (secrets, logs, fail-closed).
4. **Bugfix** (crash, regressao).
5. **Refactor** (sem mudanca funcional).
6. **Feature** (por ultimo).

## Squash vs merge commit vs rebase

Padrao: **squash merge**.

Exceto:
- PR que eh explicitamente "cherry-pick preservation" — usar rebase para
  manter autoria dos commits originais.
- PR de rebase de branch antiga sobre main — merge commit para preservar
  ponto de convergencia.

## Pos-merge

- Deletar branch remota imediatamente (auto via GitHub).
- Se o PR afetou secrets/env, confirmar deploy em homologacao antes de
  produzir artefato de prod.
