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
RUN curl -fsSL https://chatgpt.com/codex/install.sh -o /tmp/codex-install.sh \
    && printf '%s\n' 'dd4282a1a3c8188f792513f2f16afb852e63ce3b98dbbc67684f716ebcc1e862  /tmp/codex-install.sh' \
       | sha256sum --check --strict \
    && CODEX_NON_INTERACTIVE=1 sh /tmp/codex-install.sh --release 0.155.0 \
    && test "$(codex --version)" = 'codex-cli 0.155.0' \
    && rm /tmp/codex-install.sh

WORKDIR /workspaces/astro-clock
