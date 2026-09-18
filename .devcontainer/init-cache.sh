#!/bin/sh
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# The only sudo permission granted to developer is this root-owned helper,
# without arguments. Named volumes may retain a previous container user's UID.
[ "$#" -eq 0 ] || exit 2
[ "$(id -u)" -eq 0 ] || exit 2
cache_uid=$(id -u developer)
cache_gid=$(id -g developer)
for cache_dir in /var/cache/astro-clock/output /var/cache/astro-clock/downloads /var/cache/astro-clock/ccache; do
    [ -d "$cache_dir" ] && [ ! -L "$cache_dir" ] || exit 2
    find "$cache_dir" -xdev \( ! -uid "$cache_uid" -o ! -gid "$cache_gid" \) \
        -execdir chown -h "$cache_uid:$cache_gid" {} +
done
