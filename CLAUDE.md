# grokbot-docker: project context

One Docker image: the official Grok Bot Linux app in a browser desktop, plus an agent-CLI toolbox.
Target: Synology NAS, x86-64 first. See README.md for the user guide.

## Layout

```
docker-compose.yml, .env.example, portainer/stack.yml   deploy
image/Dockerfile                                         FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie
image/root/                                              overlay copied to /
.github/workflows/build.yml                              amd64 build → ghcr.io/<owner>/grokbot-docker
```

## Key facts

- Grok Bot is not in the image. `install-grokbot` runs apt as a normal user with private state
  (`~/.cache/grokbot-nas/apt-<package>`, `APT_CONFIG`) against `https://downloads.cursor.com/aptrepo`
  suite `grok-bot`. It checks the signature with `image/root/usr/share/grokbot-nas/grok-bot.asc`
  (taken from the package's postinst; fingerprint ends `42A1772E62E492D6`), then unpacks
  `/opt/Grok Bot` into `~/.local/opt/grok-bot/<version>` and points `current` at it.
- The package (`grok-bot`, Electron 42) installs `/opt/Grok Bot/grok-bot` and
  `grok-bot.desktop` with `x-scheme-handler/grokbot` and `sand`. Its data is in
  `~/.config/Grok Bot` (`SAND_USER_DATA_DIR` changes it).
- Sign-in is Cursor's polling flow: the app opens `cursor.com/loginDeepControl?challenge&uuid`
  and polls `api2.cursor.sh/auth/poll` (about 20 min). Any browser on any device works. The app
  awaits `openExternal` and a rejection can fail the sign-in, so `grokbot-open-url` (the http/https
  handler in `/usr/share/applications/mimeapps.list`, and `$BROWSER`) always exits 0: it opens
  Chrome when installed, else copies the link (wl-copy / xclip) and shows it in a window.
- MCP OAuth can return to `localhost:8787` in the container: that needs Chrome in the container.
- Chrome is optional: `install-chrome` uses the same code (`/usr/local/lib/grokbot-nas/user-apt.sh`)
  with Google's repo. The Dockerfile downloads Google's key at build time.
- The app quits when it cannot take its single-instance lock. The `grok-bot` wrapper removes
  stale `Singleton*` files; compose sets a fixed `hostname`.
- Release feed (not used by the installer): `https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand`.
- `HOME=/config`, user `abc` (`PUID`/`PGID`). Agent CLIs go to `/config/.local/bin` and
  `/config/.npm-global/bin`.
- Extra services are s6-rc longruns: `svc-ttyd` (`TTYD=1`), `svc-sshd` (`SSHD=1`), `svc-startup`.
  Disabled services `exec sleep infinity`.
- `/defaults/autostart*` and `/defaults/menu*.xml` are copied to `/config` on first start only.
  Keep logic in `/usr/local/bin/grokbot-session`, not in the autostart file.

## Checks

```
shellcheck -x image/root/usr/local/bin/* image/root/etc/s6-overlay/s6-rc.d/*/run
docker compose config
```
