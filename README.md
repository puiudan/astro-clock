# astro-clock

Buildroot platform scaffold for the STM32MP157C-DK2 astronomical clock.
The current milestone is a minimal serial console and Ethernet platform.
The application and UI are not included. The complete Buildroot build passed
inside the non-root Dev Container, including root filesystem and SD image
generation.
No board test has been performed.

## Pinned sources

Buildroot **2025.02.18 LTS**, released 2026-09-10, is supported through March
2028 according to the [official release table](https://buildroot.org/download.html).
The `third_party/buildroot` Git submodule records the exact release commit
`d030e36bbc9669230c015be971b14b6e062cfdde`; its annotated tag object is
`b611e07ef088c70c1e21f77c30872bce97a1f1c2`.
The tag was resolved against the official GitLab repository on 2026-09-18.
The official [release source archive](https://buildroot.org/downloads/buildroot-2025.02.18.tar.xz)
has SHA-256:

```text
e38ad1df6ea0479fff6419a87a64535d02131674d463be154a763ef725b55321
```

The archive checksum was computed from the HTTPS download; this setup does
not claim PGP signature verification. The archive is not part of this repository.

The Dev Container uses the official Debian `bookworm-20260824` multiarch image
index, verified directly against Docker Registry on 2026-09-18:

```text
sha256:6ebd97fa83deb272194a2cf015b3d26a4d538e9ad3a7a79d544c8af5b0a01443
```

Debian packages come from the fixed `20260910T000000Z` Debian and
Debian-security snapshots. Their signed repository metadata is still checked;
only expiration is disabled for these historical snapshots. Updating dependencies
requires an intentional Dockerfile change and rebuilding the container.

Codex CLI is installed in the image as `developer`, pinned to **0.155.0**
through the [official standalone installer](https://chatgpt.com/codex/install.sh).
The installer downloaded on 2026-09-18 is verified before execution using
SHA-256 `dd4282a1a3c8188f792513f2f16afb852e63ce3b98dbbc67684f716ebcc1e862`.
The image build checks that `codex --version` reports `codex-cli 0.155.0`.
If the installer changes, rebuilding fails until its replacement is reviewed
and the Dockerfile checksum is updated intentionally. Codex is available on
`PATH` through `/home/developer/.local/bin`; its default state location is used.

## Open the Dev Container

On a development host with Docker and VS Code's Dev Containers extension
already installed, clone this repository, then initialize its pinned submodule:

```sh
git submodule update --init --recursive
```

Open the repository folder in VS Code and run **Dev Containers: Reopen in
Container**. The first open builds the development image and installs tools
inside that image; it does not install software on the Debian host. If Docker
or the extension is missing, install those separately with host administrator
approval. Container creation needs network access to Docker Registry and Debian
snapshots. It never configures or builds firmware automatically.

With the already installed Dev Container CLI, create or start the container
before opening its shell:

```sh
cd /home/dan/astro-clock
devcontainer up --workspace-folder /home/dan/astro-clock
devcontainer exec --workspace-folder /home/dan/astro-clock bash
```

`Dev container not found` means `exec` could not find a running container for
that workspace. Run `up` successfully with the same absolute workspace path
first, then retry `exec`. The first `up` builds the development image only;
it does not build firmware.

On this host, Docker and the CLI are installed, but the current user cannot
access Docker's socket. If your host requires administrator access to Docker,
run the installed CLI with sudo in your own terminal and enter your password:

```sh
sudo /home/dan/.devcontainers/bin/devcontainer up --workspace-folder /home/dan/astro-clock --update-remote-user-uid-default never
sudo /home/dan/.devcontainers/bin/devcontainer exec --workspace-folder /home/dan/astro-clock bash
```

This uses administrator access for container management; the container shell
still runs as `developer`. The sudo variant disables UID/GID adaptation to the
root CLI process and keeps the image's developer UID/GID at 1000:1000, matching
this host. Hosts with other user IDs should use the normal CLI with authorized
Docker access so UID/GID adaptation can match their workspace ownership.
These commands do not change host permissions,
install host software, or mount the Docker socket inside the container.

The container and terminal run as `developer`, with its UID/GID adapted to the
Linux host by Dev Containers. Only the fixed cache ownership helper may run via
passwordless sudo, and it accepts no arguments. It runs on each container start
to make persistent volumes writable after UID changes. Buildroot itself must run
as a non-root user; the wrapper rejects root. No privileged mode, host block
devices, or Docker socket are mounted.

Dependencies follow the selected release's
`third_party/buildroot/docs/manual/prerequisite.adoc`: GNU build tools,
compression/archive tools, source download tools, Python 3, and ncurses headers
for menuconfig. Git, CA certificates, UTF-8 locale support, and ShellCheck are
also included. Optional GUI configuration and documentation-generation tools
are omitted.

To apply Dockerfile changes, run **Dev Containers: Rebuild Container** in VS
Code. The equivalent CLI command on this host is:

```sh
sudo /home/dan/.devcontainers/bin/devcontainer up --workspace-folder /home/dan/astro-clock --update-remote-user-uid-default never --remove-existing-container
sudo /home/dan/.devcontainers/bin/devcontainer exec --workspace-folder /home/dan/astro-clock bash
```

Recreating the container preserves the three named Buildroot volumes described
below. Codex authentication is neither baked into the image nor mounted from
the host. After recreation, run `codex` in the container and sign in again.
Rebuilding the development image does not configure or build firmware.

## Configure and save changes

Inside the container terminal:

```sh
./scripts/buildroot status
make configure
make menuconfig
make savedefconfig
```

The direct equivalents are `./scripts/buildroot configure`,
`./scripts/buildroot menuconfig`, and `./scripts/buildroot savedefconfig`.
`make` with no target prints help. Configuration compiles Buildroot's small
host Kconfig utility, but does not compile firmware. `configure` resets the
working configuration to `external/configs/astro_clock_defconfig`; save desired
menuconfig changes with `savedefconfig` before configuring again.

The project defconfig starts from this pinned release's
`configs/stm32mp157c_dk2_defconfig`, with compiler caching enabled, a
`ttySTM0` login console at 115200 baud, and DHCP on `eth0`. It reuses
upstream board overlays, Linux configuration, custom-source hashes, and image
generation scripts. The external Linux fragment disables display, audio,
wireless and touchscreen support for this milestone. No board files are duplicated or vendored sources modified.
The wrapper rejects an incorrect source commit or dirty submodule, including
untracked files. Future source fixes must be reproducible patches integrated
through the external tree instead of edits to checked-out Buildroot sources.
The baseline pins Linux 6.9.8, TF-A v2.9, and U-Boot 2024.07 exactly as upstream;
Buildroot LTS support does not imply those board-selected versions are still
maintained upstream. Review those versions before deployment. Future project
packages and board overrides belong under `external/` (`BR2_EXTERNAL`).

`savedefconfig` explicitly writes to the project external tree, preserving the
upstream board defconfig. Inspect the diff before recording configuration changes:

```sh
git diff -- external/configs/astro_clock_defconfig
git status --short
```

## Firmware build and generated files

After configuration validation and authorization for regular-file image
generation, start the firmware build explicitly:

```sh
make build
# Optional bounded package compilation parallelism:
ASTRO_JOBS=4 make build
```

`ASTRO_JOBS` sets both make parallelism and Buildroot's `BR2_JLEVEL`, so
recursive package builds use the requested limit.

The full build produced `/var/cache/astro-clock/output/images/sdcard.img`
(128,380,928 bytes) and a 125,829,120-byte ext4 root filesystem (`rootfs.ext4`
is a symlink to `rootfs.ext2`). Buildroot invokes its built `mkfs.ext4` on
the regular rootfs image, then genimage assembles a GPT in the regular file
`sdcard.img`. The user explicitly authorized these regular-file operations.
Filesystem checks and primary/backup GPT integrity checks passed.
Writing an image to storage requires separate explicit approval; this project
provides no flashing command. Build success does not establish hardware boot.

The baseline permits a root login without a password over serial. No SSH
server is enabled. Use an isolated development Ethernet network and review
authentication and component maintenance before deployment.

Three Docker named volumes, scoped with Dev Containers' stable workspace
identifier, preserve state across container recreation:

| State | Container path | Named volume prefix |
| --- | --- | --- |
| Build output, `.config`, generated images | `/var/cache/astro-clock/output` | `astro-clock-output-` |
| Downloaded source archives | `/var/cache/astro-clock/downloads` | `astro-clock-downloads-` |
| Buildroot compiler cache | `/var/cache/astro-clock/ccache` | `astro-clock-ccache-` |

These volumes live in Docker-managed storage outside the Git worktree. Keep them
when recreating the container; deleting volumes destroys this cached state.
Different workspace identities use separate volumes.

Outside the container, the wrapper defaults to ignored `.build/output`,
`.build/downloads`, and `.build/ccache` beneath the repository. The environment
variables `ASTRO_OUTPUT_DIR`, `ASTRO_DOWNLOAD_DIR`, and `ASTRO_CCACHE_DIR` override
these paths; each must be absolute without whitespace. Paths are canonicalized,
and generated state is rejected inside Buildroot or the external tree, or at the
repository root. Buildroot always receives
explicit absolute `O=` and `BR2_EXTERNAL=` arguments, along with matching
`BR2_DL_DIR=` and `BR2_CCACHE_DIR=` values. Do not invoke Buildroot in its source
tree or use host package installation as a substitute for the container.

## Version-controlled files and verification

Record `.devcontainer/`, `external/`, `scripts/buildroot`, `Makefile`,
`.gitignore`, `.gitmodules`, this README, and the `third_party/buildroot` **gitlink**
(not its source contents). The repository instructions in `AGENTS.md` also point
to the documented pin. Submodule registration records `.gitmodules` and the
gitlink; the Buildroot source contents remain in their own repository. Do not record build
outputs, source archives, compiler caches, generated images, or secrets.

Static checks available without compiling firmware:

```sh
bash -n scripts/buildroot
sh -n .devcontainer/init-cache.sh
python3 -m json.tool .devcontainer/devcontainer.json >/dev/null
./scripts/buildroot status
git diff --check
git diff --cached --check
git -C third_party/buildroot status --short
```

These static checks passed on 2026-09-18; the submodule was clean. The official
remote tag and peeled commit matched the recorded pin (`git -C
third_party/buildroot ls-remote origin refs/tags/2025.02.18
'refs/tags/2025.02.18^{}'`). A fresh official archive download matched the
SHA-256 above, and Docker Registry returned the recorded Debian manifest digest.
Comparison against the upstream board defconfig confirmed that the only project
addition is `BR2_CCACHE=y`. A temporary mock `make` also verified all four
wrapper targets, their absolute paths and save destination, and rejection of
relative paths, external-tree output paths, and invalid job counts. That check
did not invoke Buildroot or compile anything.

The current host has Docker and the Dev Container CLI, but Docker socket access
is denied to the current user; sudo requires an interactive password. The host
lacks make, GCC, and ShellCheck. The development image was rebuilt and the
container recreated on 2026-09-18; a runtime check confirmed a non-root shell
and `codex-cli 0.155.0` on PATH. Kconfig validation, host dependency checks, and the static checks below
passed in the running non-root Dev Container on 2026-09-20. No container
dependency changes or rebuild were required. The full build completed on
2026-09-22; hardware boot remains unverified.
The configuration validation commands are:

```sh
shellcheck scripts/buildroot .devcontainer/init-cache.sh
make configure
test -f "$ASTRO_OUTPUT_DIR/.config"
make savedefconfig
git diff -- external/configs/astro_clock_defconfig
```
