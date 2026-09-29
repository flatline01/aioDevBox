#!/bin/bash
set -e

DESKTOP_USER="${DESKTOP_USER:-dev}"
HOME_DIR="/home/${DESKTOP_USER}"
MARKER="/data/.linux_startup_complete"

# ------------------------------------------------------------------
# VNC password (re-applied every boot in case VNC_PASSWORD changed)
# ------------------------------------------------------------------
mkdir -p "${HOME_DIR}/.vnc"
echo "${VNC_PASSWORD:-changeme123}" | tigervncpasswd -f > "${HOME_DIR}/.vnc/passwd"
chmod 600 "${HOME_DIR}/.vnc/passwd"
chown -R "${DESKTOP_USER}:${DESKTOP_USER}" "${HOME_DIR}/.vnc"

# Convenience redirect so http://host:6901/ lands straight on the client
if [ -f /usr/share/novnc/vnc.html ] && [ ! -f /usr/share/novnc/index.html ]; then
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
fi

mkdir -p /var/log/devstack /data
chown -R "${DESKTOP_USER}:${DESKTOP_USER}" /var/log/devstack /data /var/www 2>/dev/null || true

# ------------------------------------------------------------------
# Named volumes (see docker-compose.yml) mounted over paths that don't
# exist in the image get auto-created root-owned, which stops the
# desktop user (and apps like VS Code) from writing to them. Re-assert
# ownership of just the mount roots every boot — non-recursive, so it's
# instant even once these fill up with browser/extension data, and it
# repairs volumes that were already created root-owned.
# ------------------------------------------------------------------
for d in .config .mozilla .vscode; do
    mkdir -p "${HOME_DIR}/${d}"
    chown "${DESKTOP_USER}:${DESKTOP_USER}" "${HOME_DIR}/${d}"
done
mkdir -p "${HOME_DIR}/.vscode/extensions"
chown "${DESKTOP_USER}:${DESKTOP_USER}" "${HOME_DIR}/.vscode/extensions"

# ------------------------------------------------------------------
# Run startup.sh exactly once ever (marker lives on the bind-mounted
# /data volume so it survives `docker compose down` + recreation,
# not just container restarts).
# ------------------------------------------------------------------
if [ ! -f "${MARKER}" ]; then
    echo "[entrypoint] First boot — running /opt/startup.sh"
    bash /opt/startup.sh
    touch "${MARKER}"
else
    echo "[entrypoint] startup.sh already ran previously, skipping (delete ${MARKER} to force a re-run)"
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf