# pr-flow — instalacao

Skill de governanca de PRs para Claude Code. Distribuida como artefato
unico `pr-flow.skill` (tarball gzip).

## Conteudo desta pasta

| Arquivo | Proposito |
|---|---|
| `pr-flow.skill`   | artefato binario (tar.gz) com a skill empacotada |
| `manifest.json`   | metadata, checksum sha256, dependencias |
| `install.sh`      | instalador idempotente com validacao de checksum |
| `uninstall.sh`    | remocao segura (preserva backup) |
| `INSTALL.md`      | este arquivo |

## Requisitos

- macOS ou Linux (bash 4+)
- `tar`, `shasum`, `python3`
- `gh` CLI autenticado (`gh auth login`)
- Claude Code instalado (`~/.claude/` existe)
- Opcional: `orbit-engine` rodando em `localhost:9100` para rastreamento

## Instalacao

```bash
cd /pasta/que/contem/este/INSTALL.md
./install.sh
```

O instalador:
1. Valida o sha256 do `pr-flow.skill` contra o `manifest.json`.
2. Faz backup de uma instalacao previa (se existir) em `pr-flow.backup.<ts>`.
3. Extrai em `~/.claude/skills/pr-flow/`.
4. Ajusta permissoes (`chmod +x`) nos scripts.
5. Roda smoke test.

Apos instalar, **reinicie o Claude Code** para que a skill seja detectada.

## Uso rapido apos instalar

### Em um repo novo (aplica governance)

```bash
~/.claude/skills/pr-flow/scripts/apply.sh owner/repo
```

Cria labels `ready-to-merge`, `blocked`, `needs-review`, aplica branch
protection em `main` e `develop`, imprime instrucoes para copiar o
template de PR e o workflow `pr-limit.yml`.

### Antes de abrir um novo PR

```bash
~/.claude/skills/pr-flow/scripts/check.sh
# PR-FLOW OK   — pode abrir
# PR-FLOW FAIL-CLOSED — drene a fila primeiro
```

### Antes de qualquer `git commit`

```bash
~/.claude/skills/pr-flow/scripts/preflight-commit.sh
# imprime branch atual, staged files e avisos de conflito com PRs ativos
# fail-closed se estiver em main/develop
```

## Uninstall

```bash
./uninstall.sh
```

## Troubleshooting

| Sintoma | Causa | Correcao |
|---|---|---|
| `checksum nao bate` no install | artefato corrompido/adulterado | baixe novamente o `pr-flow.skill` do source oficial |
| `gh: command not found` | gh CLI ausente | `brew install gh && gh auth login` |
| `apply.sh` falha em branch protection | sem permissao admin no repo | peca a quem tem permissao ou pule esse passo |
| skill nao aparece no Claude Code | harness nao foi reiniciado | encerre e reabra o Claude Code |

## Versoes

Atual: 1.0.0 (veja `manifest.json`).
