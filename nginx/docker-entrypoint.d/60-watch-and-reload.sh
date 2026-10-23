#!/bin/sh
# nginx/docker-entrypoint.d/60-watch-and-reload.sh
#
# Polling-based on purpose, not inotify: sites.json is edited from the
# HOST, often across a Windows/Docker Desktop bind mount, and low-level
# filesystem change notifications frequently don't propagate reliably
# across that boundary — the file demonstrably changes but inotify
# events can simply never fire on the container side. Polling a
# content hash is slower (up to ~POLL_INTERVAL seconds of latency) but
# works regardless of what's on the other side of the mount.
#
# Host-originated changes (sites.json, or a manually-edited conf.d
# file) are debounced — only acted on once the same new hash is seen
# on two consecutive polls — since a file caught mid-write by the
# host<->container sync can otherwise look like two separate changes.
# The conf.d rewrite THIS script itself performs (via reprovisioning)
# is deterministic and reloads immediately, without waiting on that
# debounce.
#
# Runs after 50-provision-sites.sh (first-boot provisioning) and stays
# running in the background for the container's lifetime.
set -e
 
POLL_INTERVAL=2
 
hash_sites_json() {
    md5sum /sites.json 2>/dev/null | awk '{print $1}'
}
 
hash_conf_d() {
    cat /etc/nginx/conf.d/*.conf 2>/dev/null | md5sum | awk '{print $1}'
}
 
reload_nginx() {
    echo "[watch] testing config"
    if nginx -t 2>/tmp/nginx-test.log; then
        echo "[watch] config OK — reloading nginx"
        nginx -s reload 2>/tmp/nginx-reload.log || cat /tmp/nginx-reload.log
    else
        echo "[watch] nginx -t failed, NOT reloading:"
        cat /tmp/nginx-test.log
    fi
}
 
watch_and_reload() {
    last_sites_hash="$(hash_sites_json)"
    prev_sites_hash="$last_sites_hash"
    last_conf_hash="$(hash_conf_d)"
    prev_conf_hash="$last_conf_hash"
 
    while true; do
        sleep "$POLL_INTERVAL"
 
        sites_hash="$(hash_sites_json)"
        if [ "$sites_hash" != "$prev_sites_hash" ]; then
            echo "[watch] sites.json poll: prev=$prev_sites_hash new=$sites_hash last_acted=$last_sites_hash"
        fi
        if [ "$sites_hash" != "$last_sites_hash" ] && [ "$sites_hash" = "$prev_sites_hash" ]; then
            if [ -n "${ENV+x}" ] && [ "$ENV" = "development" ]; then
                echo "[watch] sites.json changed (last=$last_sites_hash prev=$prev_sites_hash new=$sites_hash) — reprovisioning"
            fi
            /docker-entrypoint.d/50-provision-sites.sh || echo "[watch] reprovisioning failed, see output above"
            last_sites_hash="$sites_hash"
            # conf.d was just rewritten deterministically by the line
            # above — reload now instead of waiting for the debounce
            # below to "discover" it on a later poll.
            reload_nginx
            last_conf_hash="$(hash_conf_d)"
            prev_conf_hash="$last_conf_hash"
        fi
        prev_sites_hash="$sites_hash"
 
        # Manual/direct edits to conf.d still go through the debounce,
        # since those (like sites.json) can originate from the host.
        conf_hash="$(hash_conf_d)"
        if [ "$conf_hash" != "$last_conf_hash" ] && [ "$conf_hash" = "$prev_conf_hash" ]; then
            echo "[watch] conf.d changed — testing config"
            reload_nginx
            last_conf_hash="$conf_hash"
        fi
        prev_conf_hash="$conf_hash"
    done
}


if [ -n "${ENV+x}" ] && [ "$ENV" = "development" ]; then
    echo "[watch]  DEV - Setting up watch on sites.json and conf files."
    watch_and_reload &
fi

exit 0