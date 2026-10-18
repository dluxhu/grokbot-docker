# syntax=docker/dockerfile:1
#
# GrokBot NAS image: a Linux desktop in the browser (linuxserver Selkies base,
# the same base as linuxserver/chrome) plus a toolbox for coding-agent CLIs.
#
# Grok Bot is NOT in the image. `install-grokbot` installs the official package
# into $HOME (/config) from the vendor's signed apt repository. The desktop
# session runs it on first start. Google Chrome is optional: `install-chrome`
# installs it the same way. The agent CLIs (claude, grok, cursor, ...)
# are not in the image either: `install-agents` puts them into $HOME.

ARG NODE_MAJOR=24

# tmux from source with utf8proc, so wide and unicode characters in TUIs
# render correctly.
FROM debian:trixie-slim AS tmux-build
ARG TMUX_VERSION=3.7b
RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc libc6-dev make bison pkg-config ca-certificates curl \
      libevent-dev libncurses-dev libutf8proc-dev \
    && curl -fsSL "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" | tar xz -C /tmp \
    && cd "/tmp/tmux-${TMUX_VERSION}" \
    && ./configure --enable-utf8proc && make -j"$(nproc)" && make install

FROM node:${NODE_MAJOR}-trixie-slim AS node

FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

ARG TTYD_VERSION=1.7.7
ARG YQ_VERSION=v4.44.3

# TITLE: browser tab title. PIXELFLUX_WAYLAND: labwc (true) or Xvfb + Openbox
# (false). START_DOCKER: no Docker-in-Docker.
ENV TITLE="Grok Bot" \
    PIXELFLUX_WAYLAND=true \
    START_DOCKER=false

RUN apt-get update && apt-get install -y --no-install-recommends \
      # Grok Bot runtime libraries: the Depends list of the official grok-bot .deb.
      libgtk-3-0t64 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
      libatspi2.0-0t64 libuuid1 libsecret-1-0 libasound2t64 libgbm1 \
      libxkbcommon0 libdrm2 libayatana-appindicator3-1 desktop-file-utils \
      # Libraries for the optional Google Chrome (install-chrome).
      fonts-liberation libcups2t64 libvulkan1 \
      # Clipboard tools: grokbot-open-url copies links when Chrome is absent.
      wl-clipboard xclip \
      # Toolbox for the agents.
      git ca-certificates ripgrep curl jq bash fd-find less procps unzip zip \
      xz-utils sqlite3 tree file moreutils openssh-client openssh-server \
      rsync bind9-dnsutils netcat-openbsd nano vim-tiny shellcheck \
      python3 python3-pip python3-venv python3-requests python3-yaml \
      python3-bs4 python3-lxml python3-numpy python3-pandas \
      # tmux runtime libraries.
      libevent-core-2.1-7t64 libutf8proc3 \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
    # sshd makes its host key in /config/.ssh at start. No baked-in host keys.
    && rm -f /etc/ssh/ssh_host_* \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Extra apt packages, set at build time:
#   EXTRA_PACKAGES="golang htop" docker compose up -d --build
ARG EXTRA_PACKAGES=
RUN if [ -n "$EXTRA_PACKAGES" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends $EXTRA_PACKAGES \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# GitHub CLI from GitHub's apt repository.
RUN set -eux; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update && apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*

# yq and ttyd: static binaries for the build architecture.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) ttyd_arch=x86_64 ;; \
      arm64) ttyd_arch=aarch64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}"; \
    curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"; \
    chmod +x /usr/local/bin/yq /usr/local/bin/ttyd; \
    yq --version; ttyd --version

# Node.js and npm from the official image (for the npm-based agent CLIs).
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && node --version && npm --version

COPY --from=tmux-build /usr/local/bin/tmux /usr/local/bin/tmux
RUN tmux -V \
    && printf 'set -g default-terminal "tmux-256color"\nset -ga terminal-overrides ",*:Tc"\n' > /etc/tmux.conf

# User installs go to $HOME (/config), so they survive image updates:
#   pip install --user → /config/.local
#   npm install -g     → /config/.npm-global
#   install-agents     → /config/.local/bin and /config/.npm-global/bin
# /etc/profile.d/grokbot-nas.sh sets the same for ssh login shells.
ENV PIP_BREAK_SYSTEM_PACKAGES=1 \
    NPM_CONFIG_PREFIX=/config/.npm-global \
    PATH="/config/.local/bin:/config/.npm-global/bin:${PATH}" \
    BROWSER=grokbot-open-url

COPY root/ /
RUN chmod +x /usr/local/bin/* /etc/s6-overlay/s6-rc.d/*/run \
    # Google's signing key for install-chrome. Each image build gets the
    # current key.
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
         -o /usr/share/grokbot-nas/google-chrome.asc

# 3000 = desktop over HTTP (for a reverse proxy), 3001 = desktop over HTTPS,
# 7681 = ttyd web terminal (TTYD=1), 2222 = sshd (SSHD=1).
EXPOSE 3000 3001 7681 2222
VOLUME /config
