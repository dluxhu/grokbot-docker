# grokbot-docker

Run the official **Grok Bot** Linux desktop app on a Synology NAS (or any Docker host), and use it
from your browser. The same container also has a toolbox for coding-agent CLIs: Claude Code,
Grok Build, Cursor Agent, Codex, Gemini and more.

- **Desktop in the browser.** The image is built on linuxserver's
  [Selkies base](https://docs.linuxserver.io/images/docker-baseimage-selkies/), the same base as
  [linuxserver/chrome](https://docs.linuxserver.io/images/docker-chrome). Open `https://your-nas:3001`
  to see the Grok Bot window.
- **Grok Bot is not in the image.** `install-grokbot` installs the official package into your home
  folder from the vendor's signed apt repository. The desktop does this for you on first start.
  The app stays on the volume, so it survives image updates.
- **Google Chrome is optional.** `install-chrome` installs it into your home folder the same way,
  from Google's signed repository, and the desktop keeps it up to date. Without Chrome, web links
  show in a window and go to the clipboard, so you open them in the browser on your computer.
- **Agent CLIs are not in the image.** `install-agents` installs them into your home folder, as in
  [claude-syno-nas](https://github.com/dluxhu/claude-syno-nas).
- **Optional terminal doors.** A web terminal (ttyd, `TTYD=1`) and key-only ssh (`SSHD=1`).

Status: first version, x86-64 only.

## What you need

- A Synology NAS with an x86-64 CPU, DSM 7.2 or newer, and Container Manager. Any x86-64 Docker
  host also works.
- A few GB of disk for the image, and about 400 MB for Grok Bot.
- A Cursor account with a plan that includes Grok Bot. Grok Bot uses your Cursor login.

## Setup

1. Copy this project to the NAS, for example to `/volume1/docker/grokbot`.
2. Over SSH, make the home folder and give it to your user (`id` shows your UID and GID):

   ```
   sudo mkdir -p /volume1/docker/grokbot/home
   sudo chown -R 1026:100 /volume1/docker/grokbot/home
   ```

3. Make the config file and set at least `PUID`, `PGID`, `HOME_DIR` and `GUI_PASS`:

   ```
   cd /volume1/docker/grokbot
   cp .env.example .env
   ```

4. Start it, from Container Manager (Project → Create → this folder) or over SSH:

   ```
   sudo docker compose up -d
   ```

   This pulls the prebuilt image from GHCR. Add `--build` to build it on the NAS.

5. Open `https://your-nas:3001`. Accept the self-signed certificate. Log in with `GUI_USER` /
   `GUI_PASS`.

On first start, a terminal window installs Grok Bot (about 100 MB), then Grok Bot opens.

## Sign in to Grok Bot

1. In Grok Bot, choose **Sign in**. A window shows the sign-in link, and the link is on the
   clipboard.
2. Open the link in the browser on your computer (or any device) and sign in to your Cursor
   account.
3. Grok Bot gets the login by itself after a few seconds. You have about 20 minutes.

This works because Grok Bot polls Cursor's server for the result. The browser does not have to
reach the container. If the browser asks to open a `grokbot` link at the end, you can cancel it.

With Google Chrome installed (`install-chrome`), the link opens in Chrome inside the desktop
instead. Some connector logins (MCP OAuth) return to `localhost` in the container; these need
Chrome in the container.

The login is kept in `<home folder>/.config/Grok Bot`.

## Google Chrome (optional)

```
install-chrome            # install the newest version, or update to it
install-chrome --check    # show the installed and the newest version
install-chrome --remove   # remove Chrome; your Chrome profile stays
```

The desktop menu has **Google Chrome** and **Install or update Chrome**. With
`CHROME_AUTO_UPDATE=true` (the default), an installed Chrome updates on each container start.
Chrome goes into `~/.local/opt/google-chrome/<version>` and its profile into
`~/.config/google-chrome`. All web links (from Grok Bot, `gh`, agent CLIs) open in Chrome when it
is installed.

## Install and update Grok Bot

With `GROKBOT_AUTO_UPDATE=true` (the default), the desktop installs Grok Bot on first start and
updates it on each container start. By hand, in any terminal in the container:

```
install-grokbot           # install the newest version, or update to it
install-grokbot --check   # show the installed and the newest version
install-grokbot --remove  # remove the app; your Grok Bot data stays
```

The desktop menu (right-click on the desktop) also has **Update Grok Bot**. Restart Grok Bot after
an update.

The installer uses apt with the vendor's repository (`https://downloads.cursor.com/aptrepo`) and
its signing key, which is in the image. apt checks the signature and the package hash. Then the
installer unpacks the package into `~/.local/opt/grok-bot/<version>`. It keeps the previous
version. It does not need root. `install-chrome` works the same way with Google's repository.

## Install the agent CLIs

In a terminal in the container (desktop menu → Terminal, ttyd, or ssh):

```
install-agents list           # show all
install-agents claude grok    # install some
install-agents all            # install all
```

They go into `~/.local/bin` and `~/.npm-global/bin`, which are on `PATH`. They persist across image
updates. The vendor-installer ones update themselves; update the npm ones with `npm update -g`.

The image also has `git`, `gh`, `tmux`, `ripgrep`, `fd`, `jq`, `yq`, `sqlite3`, `shellcheck`, Node.js
and npm, and Python 3 with `requests`, `pandas`, `numpy` and BeautifulSoup. `pip install --user`
and `npm install -g` go to the home folder.

## Terminal doors (optional)

- `TTYD=1`: a web terminal on `http://your-nas:7681`. Set `TTYD_USER` and `TTYD_PASS`.
  `TTYD_SHELL=claude` starts Claude Code instead of bash.
- `SSHD=1`: key-only ssh. Put your public key in `<home folder>/.ssh/authorized_keys` first.
  Connect with `ssh -p 2222 abc@your-nas`. The host key is made on first start and kept in
  `<home folder>/.ssh/`.

## Startup script

The container runs `<home folder>/.config/startup.sh` as your user at each start. Its output goes
to `<home folder>/.config/startup.log`. Use it, for example, to start a tmux session.

## The home folder

`HOME_DIR` is the only host folder the container sees. It is `/config` (= `$HOME`) in the
container. It holds Grok Bot, the agent CLIs, all logins, ssh keys and your projects. Do not put
anything in it that you would not give to an agent.

| Path in the home folder | What |
|---|---|
| `.local/opt/grok-bot/` | Grok Bot app versions |
| `.local/opt/google-chrome/`, `.config/google-chrome/` | Chrome (optional) and its profile |
| `.config/Grok Bot/` | Grok Bot data and login |
| `.local/bin/`, `.npm-global/` | agent CLIs |
| `.config/labwc/`, `.config/openbox/` | desktop autostart and menu (copied on first start only) |
| `.ssh/` | ssh keys (`SSHD=1`) |

## Settings

All settings are in `.env`. See `.env.example` for each one.

| Setting | What it does |
|---|---|
| `PUID` / `PGID` | The user and group that run everything. |
| `HOME_DIR` | The host folder mounted as `/config`. Required. |
| `GUI_USER` / `GUI_PASS` | Login for the desktop. `GUI_PASS` is required. |
| `GUI_HTTPS_PORT` / `GUI_HTTP_PORT` | Desktop ports (3001 HTTPS, 3000 HTTP for a reverse proxy). |
| `GROKBOT_AUTO_UPDATE` | `true`: install and update Grok Bot at each start. |
| `CHROME_AUTO_UPDATE` | `true`: update Chrome at each start, if it is installed. |
| `PIXELFLUX_WAYLAND` | `true`: Wayland desktop. `false`: X11 desktop. |
| `TTYD`, `TTYD_USER`, `TTYD_PASS`, `TTYD_PORT`, `TTYD_SHELL` | Web terminal. |
| `SSHD`, `SSH_PORT` | Key-only ssh. |
| `CLAUDE_CODE_OAUTH_TOKEN` | Optional token for headless `claude -p`. |
| `EXTRA_PACKAGES` | Extra Debian packages for a local `--build`. |

Grok Bot reads extra Electron flags from `GROKBOT_FLAGS` or from
`<home folder>/.config/grok-bot-flags.conf` (one flag per line).

The base image has many more settings (`SELKIES_*`, `NO_DECOR`, `TITLE`, GPU settings). See the
[Selkies base image docs](https://docs.linuxserver.io/images/docker-baseimage-selkies/).

## Reverse proxy

To use HTTPS with your own hostname, use Synology's reverse proxy: **Control Panel → Login Portal →
Advanced → Reverse Proxy → Create**. Source: HTTPS, your hostname, port 443. Destination: HTTP,
`localhost`, port `3000`. On the **Custom Header** tab, add **WebSocket**. Do not expose the ports
directly to the internet; use the reverse proxy, a VPN or the firewall.

## How it is locked down

- The container sees only the home folder.
- The desktop needs a password. The ssh door accepts keys only.
- Everything runs as your user (`abc` with your `PUID`/`PGID`). Only the init system runs as root.
- No Docker socket.

This is less strict than claude-syno-nas: linuxserver images start as root to set up the user, so
`cap_drop: ALL` is not possible. The `abc` user has `sudo` in the container. Chrome and Grok Bot
run with `--no-sandbox`, because their own sandbox needs privileges that the container does not
have. The container is the sandbox.

## Updating

```
sudo docker compose pull && sudo docker compose up -d
```

Grok Bot and the agent CLIs are in the home folder, so an image update does not touch them.

## Troubleshooting

- **The desktop is black or does not start.** Set `PIXELFLUX_WAYLAND=false` (X11 mode) and
  recreate the container. If it still fails, enable `seccomp=unconfined` in `docker-compose.yml`
  (old kernels can block new syscalls).
- **Grok Bot does not open.** Open a terminal (right-click → Terminal) and run `grok-bot`. The
  error shows in the terminal.
- **Grok Bot shows "Update required".** Run `install-grokbot`, then restart Grok Bot.
- **Sign-in does not finish.** Open the link from the "Open this link" window within about 20
  minutes. The link is also in `<home folder>/.cache/grokbot-nas/last-url`. Each **Sign in** makes
  a new link; use the newest one.
- **A menu or autostart change in a new image has no effect.** The desktop copies them into the
  home folder on first start only. Delete `.config/labwc/` (or `.config/openbox/`) in the home
  folder and restart.
- **`claude: command not found`.** Run `install-agents claude`.
- **Logs:** `sudo docker logs grokbot`.

## What's in here

```
docker-compose.yml           the stack (pulls GHCR by default; --build builds ./image)
.env.example                 settings
image/Dockerfile             the image: Selkies desktop + Grok Bot and Chrome libraries + toolbox
image/root/                  files copied into the image
  usr/local/bin/install-grokbot   installs or updates Grok Bot into $HOME
  usr/local/bin/grok-bot          starts Grok Bot with container flags
  usr/local/bin/install-chrome    installs or updates Google Chrome into $HOME (optional)
  usr/local/bin/google-chrome     starts Chrome with container flags
  usr/local/bin/grokbot-open-url  web-link handler: Chrome, or show and copy the link
  usr/local/lib/grokbot-nas/      shared code of the two installers
  usr/local/bin/grokbot-session   desktop autostart: install or update, then start Grok Bot
  usr/local/bin/install-agents    installs the agent CLIs into $HOME
  etc/s6-overlay/s6-rc.d/         ttyd, sshd and startup-script services
portainer/stack.yml          Portainer stack
.github/workflows/build.yml  builds the image and pushes it to GHCR
```

## Thanks

Built on [linuxserver.io Selkies](https://github.com/linuxserver/docker-baseimage-selkies) and
[ttyd](https://github.com/tsl0922/ttyd). The agent setup comes from
[claude-syno-nas](https://github.com/dluxhu/claude-syno-nas). Grok Bot is a product of xAI and
Cursor; this project is not affiliated with them.
