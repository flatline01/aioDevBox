# devstack

A docker-compose based dev environment. Starting point: a single `linux`
desktop machine, with the stack structured so new services can be added incrementally.

## Layout

```
.
├── docker-compose.yml    # network + services
├── .env                  # shared config for every container
├── mysql/                # MySql database files
├── data/                 # general persistent data, shared across services
├── logs/                 # centralized logs, shared across services
├── linux/                # the desktop machine
│   ├── Dockerfile
│   ├── entrypoint.sh     # runs startup.sh once, then launches supervisord
│   ├── startup.sh        # YOUR one-time provisioning script
│   ├── supervisord.conf  # manages Xvnc + noVNC
│   ├── xstartup          # launches XFCE inside the VNC session
│   ├── scripts           # misc bash scripts for site admin
│   ├── php               # custom php ini and confs
│   └── persist           # linux user settings, persists between docker builds
│       └── Desktop       # linux desktop, shared with host
├── nginx/                # Webserver and SSL termination
├── mongo/                # Mongo server
├── node/                 # (empty for now)
├── redis/                # (empty for now)
└── sites/                # bind-mounted into linux at /var/www
```

Project also has a phpMyAdmin and Mongo-express admin machines available. These are available in the desktop at the following addresses:
* http://phpmyadmin || http://localhost:8081/ (on the host machine)


## Linux Desktop

![Desktop](/static/Screenshot_2026-10-24_14-49-35.png)

Currently installed:
* VSCode
* Firefox
* Bruno

## Quick start

```bash
docker compose up -d --build
```

Then connect to the desktop:

- **Browser (noVNC):** http://localhost:6901/vnc.html — password from `VNC_PASSWORD` in `.env`
- **VNC client:** `localhost:5901` — same password

The `sites/` folder on your host is mounted at `/var/www/` inside the
container, so anything you drop there (or that the container writes there)
is shared with your local filesystem.

## First-boot provisioning (`startup.sh`)

`linux/startup.sh` runs exactly once — the first time the container ever
starts. A marker file at `data/.linux_startup_complete` (on the bind-mounted
`./data` folder, so it survives container recreation) prevents it from
running again. To force it to run again, delete that marker file and
recreate the container:

```bash
rm data/.linux_startup_complete
docker compose up -d --force-recreate linux
```

Edit `linux/startup.sh` to add whatever one-time setup you need (cloning
repos into `/var/www`, installing VS Code extensions, etc.) — it already
has commented examples.

## VS Code

VS Code (the desktop app, not code-server) is installed via Microsoft's
official apt repo and available from the XFCE application menu, or by
running `code` in a terminal inside the desktop.

## GPU acceleration

GPU acceleration is **best-effort and opt-in**:

1. On the **host**, install the NVIDIA driver and the
   [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
2. In `docker-compose.yml`, uncomment the `deploy.resources.reservations`
   and `environment` block under the `linux` service.
3. Set `ENABLE_GPU=true` in `.env` (informational — the compose block above
   is what actually grants the GPU).
4. Rebuild: `docker compose up -d --build linux`.

The container ships [VirtualGL](https://virtualgl.org/), which lets you run
GPU-bound applications through the GPU passed into the container:

```bash
vglrun glxgears        # test
vglrun <your-app>
```

Without a GPU reservation, everything still works — Mesa falls back to
software rendering (llvmpipe) automatically.

## Adding the other services

`docker-compose.yml` already has commented-out stubs for `redis` and
`node` wired to the shared `.env`, the `devstack` network, and
the `sites`/`data`/`logs` volumes. Uncomment and flesh out as needed —
`node/`  will need its own `Dockerfile`s (same pattern as
`linux/`), while `redis` can run straight off official images.
