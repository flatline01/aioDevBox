########################################################################
# linux/Dockerfile
#
# XFCE desktop machine reachable via:
#   - browser (noVNC)  -> http://localhost:${LINUX_NOVNC_PORT}/vnc.html
#   - a VNC client      -> localhost:${LINUX_VNC_PORT}
#
# Includes VS Code (desktop app) and best-effort GPU acceleration via
# VirtualGL when the container is run with an NVIDIA GPU reservation
# (see docker-compose.yml). Without a GPU it falls back to software
# rendering (llvmpipe) automatically — nothing breaks either way.
########################################################################

FROM ubuntu:22.04

ARG DESKTOP_USER=dev
ARG DESKTOP_UID=1000
ARG DESKTOP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    DESKTOP_USER=${DESKTOP_USER} \
    HOME=/home/${DESKTOP_USER} \
    DISPLAY=:1 \
    ELECTRON_DISABLE_SANDBOX=1

# ------------------------------------------------------------------
# Base OS, desktop environment, VNC + noVNC, GL/Vulkan libs, utilities
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo curl wget gnupg2 ca-certificates apt-transport-https \
        software-properties-common lsb-release \
        xfce4 xfce4-goodies xfce4-terminal \
        elementary-xfce-icon-theme adwaita-icon-theme hicolor-icon-theme \
        librsvg2-common shared-mime-info at-spi2-core \
        tigervnc-standalone-server tigervnc-common tigervnc-tools \
        novnc websockify \
        dbus-x11 x11-xserver-utils xfonts-base \
        mesa-utils libgl1-mesa-dri libglx-mesa0 vulkan-tools \
        libglvnd0 libgl1 libglx0 libegl1 libgles2 \
        git gh vim nano htop unzip zip build-essential jq \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

# Sanity check: fail the build loudly here (not three layers later) if the
# tigervnc package layout ever changes and these binaries move.
RUN test -x /usr/bin/tigervncserver && test -x /usr/bin/tigervncpasswd

# D-Bus needs a machine-id to start a working session bus. Without it,
# xfce4-session comes up but xfconfd/xfdesktop silently fail, which shows
# up as: no desktop icons, no wallpaper, no right-click desktop menu.
RUN mkdir -p /var/lib/dbus \
    && dbus-uuidgen > /etc/machine-id \
    && dbus-uuidgen > /var/lib/dbus/machine-id

# ------------------------------------------------------------------
# VS Code (desktop application, via Microsoft's official apt repo)
# ------------------------------------------------------------------
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg \
    && install -D -o root -g root -m 644 /usr/share/keyrings/microsoft.gpg /etc/apt/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y --no-install-recommends code \
    && rm -rf /var/lib/apt/lists/* /usr/share/keyrings/microsoft.gpg

# ------------------------------------------------------------------
# Firefox — the "firefox" apt package on Ubuntu 22.04+ is just a snap
# stub that doesn't work in containers (no snapd/systemd), so pull the
# real .deb build from Mozilla's official apt repo instead.
# ------------------------------------------------------------------
RUN install -d -m 0755 /etc/apt/keyrings \
    && wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
        > /etc/apt/keyrings/packages.mozilla.org.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla.list \
    && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        > /etc/apt/preferences.d/mozilla \
    && apt-get update && apt-get install -y --no-install-recommends firefox \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# Google Chrome — no apt repo installed by default; fetch Google's
# official .deb directly and let apt resolve its dependencies.
# ------------------------------------------------------------------
RUN wget -q -O /tmp/chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# VirtualGL — lets GPU-bound apps be launched with `vglrun <app>` so
# they render using the host GPU (when passed through) instead of
# software rendering. Safe to have installed even with no GPU.
# ------------------------------------------------------------------
ARG VIRTUALGL_VERSION=3.1.1
RUN wget -q https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb \
        -O /tmp/virtualgl.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/virtualgl.deb \
    && rm -f /tmp/virtualgl.deb \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# Non-root desktop user
# ------------------------------------------------------------------
RUN groupadd -g ${DESKTOP_GID} ${DESKTOP_USER} \
    && useradd -m -u ${DESKTOP_UID} -g ${DESKTOP_GID} -s /bin/bash ${DESKTOP_USER} \
    && usermod -aG sudo ${DESKTOP_USER} \
    && echo "${DESKTOP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${DESKTOP_USER} \
    && mkdir -p /var/log/devstack /data /var/www \
    && chown -R ${DESKTOP_USER}:${DESKTOP_USER} /var/log/devstack /data /var/www

# ------------------------------------------------------------------
# PHP 8 (FPM + CLI) + Composer
#
# - A single php.ini (bind-mounted from the host over /etc/php/8.1/php.ini
#   — see docker-compose.yml) governs both SAPIs: the packages' own
#   cli/php.ini and fpm/php.ini are replaced with symlinks to it.
# - php-fpm listens on 0.0.0.0:9000 (not the default unix socket) so the
#   nginx container can reach it at linux:9000 over the devstack network.
# - The fpm pool runs as ${DESKTOP_USER} instead of www-data, matching
#   the ownership of the bind-mounted /var/www.
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        php8.1 php8.1-fpm php8.1-cli php8.1-common \
        php8.1-mysql php8.1-curl php8.1-mbstring php8.1-xml \
        php8.1-zip php8.1-gd php8.1-bcmath php8.1-intl php8.1-opcache \
    && rm -rf /var/lib/apt/lists/*

RUN rm -f /etc/php/8.1/cli/php.ini /etc/php/8.1/fpm/php.ini \
    && ln -s /etc/php/8.1/php.ini /etc/php/8.1/cli/php.ini \
    && ln -s /etc/php/8.1/php.ini /etc/php/8.1/fpm/php.ini

RUN sed -i \
        -e 's#^listen = .*#listen = 0.0.0.0:9000#' \
        -e '/^listen\.owner/d' -e '/^listen\.group/d' -e '/^listen\.mode/d' \
        -e "s#^user = .*#user = ${DESKTOP_USER}#" \
        -e "s#^group = .*#group = ${DESKTOP_USER}#" \
        /etc/php/8.1/fpm/pool.d/www.conf

# /run/php is normally created by a systemd tmpfiles rule on package
# install; there's no systemd here, so php-fpm's pidfile directory
# never gets created and FPM fails to start. Create it explicitly.
RUN mkdir -p /run/php

# Composer, with the official signature verification step
RUN EXPECTED_SIGNATURE="$(wget -qO- https://composer.github.io/installer.sig)" \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")" \
    && if [ "${EXPECTED_SIGNATURE}" != "${ACTUAL_SIGNATURE}" ]; then \
        echo "ERROR: composer installer signature mismatch" >&2 && rm composer-setup.php && exit 1; \
       fi \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php

# WP-CLI — for managing WordPress installs from the command line.
# default-mysql-client is included so `wp db import/export/cli` (which
# shell out to mysql/mysqldump) work against the mysql container.
RUN apt-get update && apt-get install -y --no-install-recommends default-mysql-client less \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && wp --info --allow-root

# ------------------------------------------------------------------
# nvm + Node.js — nvm lives in $HOME/.nvm and wires itself into
# ~/.bashrc, so it has to install as the desktop user, not root. The
# default LTS Node it installs is then symlinked onto the system PATH
# so `node`/`npm`/`npx` also work outside an interactive shell (VS
# Code tasks, desktop launchers) without sourcing nvm first.
# ------------------------------------------------------------------
ENV NVM_DIR=/home/${DESKTOP_USER}/.nvm

RUN su - ${DESKTOP_USER} -c '\
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
        && . "$HOME/.nvm/nvm.sh" \
        && nvm install --lts \
        && nvm alias default node \
    '

RUN ln -sf /home/${DESKTOP_USER}/.nvm/versions/node/*/bin/node /usr/local/bin/node \
    && ln -sf /home/${DESKTOP_USER}/.nvm/versions/node/*/bin/npm /usr/local/bin/npm \
    && ln -sf /home/${DESKTOP_USER}/.nvm/versions/node/*/bin/npx /usr/local/bin/npx

# ------------------------------------------------------------------
# VNC xstartup — launches the XFCE session inside the VNC display
# ------------------------------------------------------------------
COPY xstartup /home/${DESKTOP_USER}/.vnc/xstartup
# Strip any CRLF line endings before anything else — a script saved with
# Windows-style line endings breaks its own shebang (the kernel looks for
# an interpreter literally named "/bin/bash\r", which doesn't exist, and
# reports it as the script itself being missing). Doing this at build
# time makes the image immune to how the file gets saved on disk.
RUN sed -i 's/\r$//' /home/${DESKTOP_USER}/.vnc/xstartup \
    && chmod +x /home/${DESKTOP_USER}/.vnc/xstartup \
    && chown -R ${DESKTOP_USER}:${DESKTOP_USER} /home/${DESKTOP_USER}/.vnc

# ------------------------------------------------------------------
# Supervisor config (manages Xvnc + websockify/noVNC)
# ------------------------------------------------------------------
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN sed -i 's/\r$//' /etc/supervisor/conf.d/supervisord.conf

# ------------------------------------------------------------------
# One-time startup script + entrypoint that runs it exactly once
# (tracked via a marker file on the bind-mounted /data volume, so it
# survives container recreation, not just restarts).
# ------------------------------------------------------------------
COPY startup.sh /opt/startup.sh
COPY entrypoint.sh /opt/entrypoint.sh
RUN sed -i 's/\r$//' /opt/startup.sh /opt/entrypoint.sh \
    && chmod +x /opt/startup.sh /opt/entrypoint.sh

# ------------------------------------------------------------------
# Final ownership pass. ENV HOME=/home/${DESKTOP_USER} is set globally
# near the top of this file, which means every RUN step above that
# still executes as root (apt/package post-install scripts for
# Chrome, Firefox, Composer, VirtualGL, etc.) also had HOME pointed at
# the desktop user's home directory. Any of those that respect $HOME
# (common for GTK/desktop package cache dirs) could have written into
# it while running as root, leaving stray root-owned files behind —
# which is exactly what broke xfconfd (couldn't write its config dir).
# Re-assert ownership of the whole home directory now that every
# install is done, so nothing upstream of this line can leave it in a
# broken state.
RUN chown -R ${DESKTOP_USER}:${DESKTOP_USER} /home/${DESKTOP_USER}

EXPOSE 5901 6901

ENTRYPOINT ["/opt/entrypoint.sh"]