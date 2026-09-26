#!/bin/bash
########################################################################
# startup.sh — runs exactly ONCE, on the container's first boot ever
# (see entrypoint.sh / the /data/.linux_startup_complete marker).
#
# Put one-time provisioning here: cloning repos into /var/www, installing
# project dependencies, configuring VS Code extensions/settings, etc.
# This does NOT run again on `docker compose restart` or `docker compose
# up` for an existing container — only after a fresh `docker compose up`
# with no prior marker (e.g. after deleting ./data/.linux_startup_complete
# or tearing the stack down and rebuilding data from scratch).
########################################################################
set -e

echo "[startup.sh] Running one-time provisioning..."

# Example: install a couple of useful VS Code extensions
# sudo -u "${DESKTOP_USER}" code --install-extension ms-python.python
# sudo -u "${DESKTOP_USER}" code --install-extension dbaeumer.vscode-eslint

# Example: clone a project into the shared /var/www volume
# if [ ! -d /var/www/my-project ]; then
#     git clone https://github.com/your-org/my-project.git /var/www/my-project
# fi

# Example: drop a desktop shortcut
# mkdir -p "/home/${DESKTOP_USER}/Desktop"
# cp /opt/shortcuts/vscode.desktop "/home/${DESKTOP_USER}/Desktop/"

echo "[startup.sh] Done."
