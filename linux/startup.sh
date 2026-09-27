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

# ------------------------------------------------------------------
# Provision site folders from /sites.json (see docker-compose.yml for
# the mount, and the project-root sites.json for the site registry —
# same file nginx reads to generate vhosts). For each site: create its
# directory under /var/www if missing, and drop a placeholder
# index.html if the directory has no index.html or index.php yet, so
# a freshly-added site isn't just a 404/empty-listing.
# ------------------------------------------------------------------
SITES_JSON="/sites.json"

if [ -f "$SITES_JSON" ]; then
    echo "[startup.sh] Provisioning site folders from sites.json..."
    for key in $(jq -r '.sites | keys[]' "$SITES_JSON"); do
        name=$(jq -r --arg k "$key" '.sites[$k].name' "$SITES_JSON")
        directory=$(jq -r --arg k "$key" '.sites[$k].directory' "$SITES_JSON")

        if [ -z "$directory" ] || [ "$directory" = "null" ]; then
            echo "[startup.sh]   Skipping '$key' — missing directory in sites.json"
            continue
        fi

        if [ ! -d "$directory" ]; then
            echo "[startup.sh]   Creating $directory"
            mkdir -p "$directory"
        fi

        if [ ! -f "$directory/index.html" ] && [ ! -f "$directory/index.php" ]; then
            echo "[startup.sh]   Writing placeholder index.html for '$name'"
            cat > "$directory/index.php" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>$name</title>
</head>
<body>
    <h1>$name</h1>
    <?php phpinfo(); ?>
</body>
</html>
HTML
        fi
    done
else
    echo "[startup.sh] No sites.json found at $SITES_JSON — skipping site provisioning."
fi

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