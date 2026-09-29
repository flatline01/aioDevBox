#!/bin/sh
# nginx/docker-entrypoint.d/60-watch-and-reload.sh
#
# Runs alphabetically after 50-provision-sites.sh (which does the
# first-boot provisioning), and launches two background watch loops
# that persist for the life of the container:
#
#   1. Watches /sites.json — on any change, re-runs the provisioning
#      script, which regenerates every site's vhost config and
#      generates a cert for any new domain (existing certs are left
#      alone; see 50-provision-sites.sh).
#   2. Watches /etc/nginx/conf.d — on any change (from #1 above, or a
#      manual edit/add/remove of a .conf file), validates the config
#      and reloads nginx gracefully. Never restarts nginx outright —
#      a reload re-reads config without dropping active connections.
#
# Both loops run in the background (note the trailing `&`) so this
# script itself returns immediately, letting the base image's
# entrypoint proceed to actually start nginx.
set -e

watch_sites_json() {
    while inotifywait -q -e modify,create,delete,move,close_write /sites.json >/dev/null 2>&1; do
        echo "[watch] sites.json changed — reprovisioning"
        /docker-entrypoint.d/50-provision-sites.sh || echo "[watch] reprovisioning failed, see output above"
    done
}

watch_conf_d() {
    while inotifywait -q -r -e modify,create,delete,move,close_write /etc/nginx/conf.d >/dev/null 2>&1; do
        echo "[watch] conf.d changed — testing config"
        if nginx -t 2>/tmp/nginx-test.log; then
            echo "[watch] config OK — reloading nginx"
            nginx -s reload 2>/tmp/nginx-reload.log || cat /tmp/nginx-reload.log
        else
            echo "[watch] nginx -t failed, NOT reloading:"
            cat /tmp/nginx-test.log
        fi
    done
}

watch_sites_json &
watch_conf_d &

exit 0