# Official Debian multi-architecture manifest, verified 2026-09-18.
FROM debian:bookworm-20260824@sha256:6ebd97fa83deb272194a2cf015b3d26a4d538e9ad3a7a79d544c8af5b0a01443

# Freeze package repositories as well as the base image. The snapshot archives
# signed Release files; only their time-based expiry check is disabled.
RUN rm /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
       'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260910T000000Z/ bookworm main' \
       'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260910T000000Z/ bookworm-updates main' \
       'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20260910T000000Z/ bookworm-security main' \
       > /etc/apt/sources.list

# Bootstrap HTTPS trust from the pinned image's Debian archive keyring using
# HTTP snapshot URLs, then use HTTPS for all subsequent apt operations.
RUN sed -i 's|https://snapshot.debian.org|http://snapshot.debian.org|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && sed -i 's|http://snapshot.debian.org|https://snapshot.debian.org|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash bc binutils build-essential bzip2 cpio curl diffutils file \
       findutils gawk git gzip libncurses-dev locales patch perl python3 \
       rsync sed shellcheck sudo tar unzip util-linux wget which xz-utils \
    && sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 developer \
    && useradd --uid 1000 --gid developer --create-home --shell /bin/bash developer \
    && mkdir -p /var/cache/astro-clock/output /var/cache/astro-clock/downloads /var/cache/astro-clock/ccache \
    && chown -R developer:developer /var/cache/astro-clock
COPY init-cache.sh /usr/local/bin/init-astro-cache
RUN chmod 0755 /usr/local/bin/init-astro-cache \
    && printf '%s\n' 'developer ALL=(root) NOPASSWD: /usr/local/bin/init-astro-cache ""' > /etc/sudoers.d/astro-cache \
    && chmod 0440 /etc/sudoers.d/astro-cache \
    && visudo -cf /etc/sudoers.d/astro-cache

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
USER developer
ENV PATH=/home/developer/.local/bin:${PATH}

# Install the exact standalone Codex release as the development user. The
# official installer is also pinned: fail rather than execute changed content.
# Installer re-reviewed and re-pinned 2026-10-12 after upstream changed it.
RUN curl -fsSL https://chatgpt.com/codex/install.sh -o /tmp/codex-install.sh \
    && printf '%s\n' '150e3cf675682efeaac115aa3747add3f27887896d04ce6d0b56478d8b428bf6  /tmp/codex-install.sh' \
       | sha256sum --check --strict \
    && CODEX_NON_INTERACTIVE=1 sh /tmp/codex-install.sh --release 0.155.0 \
    && test "$(codex --version)" = 'codex-cli 0.155.0' \
    && rm /tmp/codex-install.sh

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

# Board access (dev loop): serial console in tmux, SSH/scp/rsync to the board.
# Versions come from the same pinned Debian snapshot. The ST-LINK VCP node is
# root:dialout (gid 20 on Debian hosts), so developer joins dialout; access is
# further limited by the device cgroup rule in devcontainer.json.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       iputils-ping openssh-client picocom python3-serial tmux \
    && rm -rf /var/lib/apt/lists/* \
    && test "$(getent group dialout | cut -d: -f3)" = 20 \
    && usermod -aG dialout developer
USER developer
# Created in the image so named volumes mounted here inherit developer
# ownership and mode 0700 on first use.
RUN install -d -m 0700 /home/developer/.ssh

WORKDIR /workspaces/astro-clock
