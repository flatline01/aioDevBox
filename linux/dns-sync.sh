#!/bin/bash
# linux/dns-sync.sh
#
# Makes every *.local hostname resolve to the nginx container from
# inside this desktop — not just domains already listed in sites.json.
# Runs dnsmasq, configured to answer *.local queries with nginx's
# current address and forward everything else (container names like
# "mysql", internet lookups) to Docker's own embedded DNS unchanged.
# nginx itself then decides what to actually serve: a known site, or
# its own catch-all (closes the connection) for anything it doesn't
# recognize — see nginx/conf.d/default.conf.
#
# Runs continuously under supervisor (see supervisord.conf), not as a
# one-time startup.sh script — the only thing that can change here is
# nginx's IP (e.g. after the nginx container is recreated), which this
# keeps re-checking for as long as the container runs.
set -e

DNSMASQ_CONF=/etc/dnsmasq.d/local-tld.conf
POLL_INTERVAL=5

resolve_nginx_ip() {
    # Uses whatever DNS is currently configured (Docker's embedded
    # resolver at this point — we haven't repointed resolv.conf yet).
    getent hosts nginx 2>/dev/null | awk '{print $1}' | head -1
}

write_dnsmasq_conf() {
    echo "address=/.local/$1" > "$DNSMASQ_CONF"
}

# Wait for nginx to be resolvable before doing anything else — it may
# not have started yet when this container boots.
ip=""
while [ -z "$ip" ]; do
    ip="$(resolve_nginx_ip)"
    [ -z "$ip" ] && sleep 2
done
echo "[dns-sync] nginx resolved to $ip"

mkdir -p /etc/dnsmasq.d
write_dnsmasq_conf "$ip"

# Point this container's own DNS resolution at dnsmasq (started below),
# so *.local works for every process here — browsers, wp-cli, curl,
# everything — not just this script's own lookups. Docker regenerates
# /etc/resolv.conf on every container start, so this runs every boot.
if ! echo "nameserver 127.0.0.1" > /etc/resolv.conf 2>/dev/null; then
    echo "[dns-sync] WARNING: could not rewrite /etc/resolv.conf (read-only in this environment?) — *.local resolution may need to be pointed at 127.0.0.1 manually"
fi

# Background: keep re-resolving nginx and rewriting the conf + telling
# dnsmasq to reload if its IP ever changes (e.g. container recreated).
(
    last_ip="$ip"
    while true; do
        sleep "$POLL_INTERVAL"
        current_ip="$(resolve_nginx_ip)"
        if [ -n "$current_ip" ] && [ "$current_ip" != "$last_ip" ]; then
            echo "[dns-sync] nginx IP changed: $last_ip -> $current_ip"
            write_dnsmasq_conf "$current_ip"
            last_ip="$current_ip"
            pkill -HUP dnsmasq 2>/dev/null || true
        fi
    done
) &

# --no-resolv + explicit --server avoids a self-referential loop now
# that /etc/resolv.conf points at 127.0.0.1 (this process) — anything
# not matched by address=/.local/... in conf-dir goes to Docker's own
# embedded DNS at 127.0.0.11. --no-daemon keeps it in the foreground
# so supervisor can track it directly.
exec dnsmasq --no-daemon --no-resolv --server=127.0.0.11 \
    --conf-dir=/etc/dnsmasq.d \
    --listen-address=127.0.0.1 --bind-interfaces \
    --log-queries
