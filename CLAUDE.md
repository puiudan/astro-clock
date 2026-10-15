# CLAUDE.md

**`AGENTS.md` is the source of truth** for this repository: Buildroot pinning,
safety rules, agent coordination and verification labels. Read it first. This
file only adds Claude Code specifics.

- Work inside the Dev Container `astro-clock-dev` (`scripts/host/dev` from the
  host). Builds: `make configure | menuconfig | savedefconfig | build`.
- Project agents live in `.claude/agents/`: `buildroot-engineer`,
  `app-developer`, `reviewer` (read-only) and `board-operator`. They mirror the
  Codex roles in `.codex/agents/`. Only **board-operator** uses `scripts/board/*`.
  Delegate board access to it rather than calling those scripts from other agents.
- Label every result STATIC / HOST-TEST / BUILD / HARDWARE. HARDWARE means the
  real STM32MP157F-DK2 was exercised through `scripts/board/*`.
- Never flash, `dd`, `mkfs` or write to `/dev/host`. Never `git push`. Host steps
  that need root are scripts under `scripts/host/` that the user runs.

## Dev loop scripts (details: `docs/dev-loop.md`)

| Command (in the container) | Purpose |
| --- | --- |
| `scripts/board/console -d` | Start the persistent serial session (tmux `board`, picocom 115200 8N1, logs in `logs/serial/`) |
| `scripts/board/serial-run [-c] "<cmd>" [timeout]` | Run a command over serial and get its output and exit status |
| `scripts/board/serial-tail [-f] [n]` | Tail the current serial log (boot logs, kernel messages) |
| `scripts/board/run "<cmd>"` | Run a command over SSH (`root@10.42.0.2`) |
| `scripts/board/deploy <local> <remote>` | Copy files to the board without reflashing (rsync, scp fallback) |
| `scripts/board/deploy-kernel [-n]` | Install zImage + DTB in /boot over SSH, keep `.prev` fallback, reboot |
| `scripts/board/ssh` | Interactive SSH to the board |
| `scripts/board/health` | Board health check with PASS/FAIL summary |
| `scripts/board/ssh-setup` | One-time dev key, `authorized_keys` and `~/.ssh/config` setup |

Host-only (the user runs them): `scripts/host/setup-board-net.sh` (sudo),
`scripts/host/flash-sd.sh` (sudo), `scripts/host/check-board-net.sh`,
`scripts/host/fetch-image`, `scripts/host/dev`.
