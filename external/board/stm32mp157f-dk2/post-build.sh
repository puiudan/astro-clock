#!/bin/sh
# Buildroot post-build script (BR2_ROOTFS_POST_BUILD_SCRIPT). $1 = TARGET_DIR.
# Installs root's SSH authorized_keys from the git-ignored local/ directory.
# The target directory persists between builds, so the file is always rewritten
# or removed to match local/authorized_keys exactly.
set -eu
target_dir=$1
board_dir=$(dirname "$0")
keys_src="$board_dir/local/authorized_keys"
keys_dst="$target_dir/root/.ssh/authorized_keys"

install -d -m 0700 "$target_dir/root" "$target_dir/root/.ssh"
if [ -s "$keys_src" ]; then
    install -m 0600 "$keys_src" "$keys_dst"
    echo "post-build: installed $(grep -c '^[^#]' "$keys_src") SSH key(s) for root"
else
    rm -f "$keys_dst"
    echo "post-build: WARNING: $keys_src missing or empty; SSH logins will be impossible" >&2
    echo "post-build: run scripts/board/ssh-setup in the dev container, then rebuild" >&2
fi
