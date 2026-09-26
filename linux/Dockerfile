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
        tigervnc-standalone-server tigervnc-common tigervnc-tools \
        novnc websockify \
        dbus-x11 x11-xserver-utils xfonts-base \
        mesa-utils libgl1-mesa-dri libglx-mesa0 vulkan-tools \
        libglvnd0 libgl1 libglx0 libegl1 libgles2 \
        firefox \
        git vim nano htop unzip zip build-essential \
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
# VNC xstartup — launches the XFCE session inside the VNC display
# ------------------------------------------------------------------
COPY xstartup /home/${DESKTOP_USER}/.vnc/xstartup
RUN chmod +x /home/${DESKTOP_USER}/.vnc/xstartup \
    && chown -R ${DESKTOP_USER}:${DESKTOP_USER} /home/${DESKTOP_USER}/.vnc

# ------------------------------------------------------------------
# Supervisor config (manages Xvnc + websockify/noVNC)
# ------------------------------------------------------------------
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ------------------------------------------------------------------
# One-time startup script + entrypoint that runs it exactly once
# (tracked via a marker file on the bind-mounted /data volume, so it
# survives container recreation, not just restarts).
# ------------------------------------------------------------------
COPY startup.sh /opt/startup.sh
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/startup.sh /opt/entrypoint.sh

EXPOSE 5901 6901

ENTRYPOINT ["/opt/entrypoint.sh"]