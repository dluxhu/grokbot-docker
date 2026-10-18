# shellcheck shell=bash
# Install a desktop app into $HOME from a signed apt repository, as a normal
# user. apt checks the repository signature and the package hash. The app goes
# into $APP_ROOT/<version>, and $APP_ROOT/current points to the active one.
#
# The calling script sets these, defines app_unpack, app_register and
# app_unregister, then calls ua_main "$@":
#   APP_TITLE APP_PKG APP_ROOT APP_BIN APP_DATA
#   REPO_URL REPO_SUITE REPO_COMPONENT REPO_KEY

APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

ua_die() { echo "$(basename "$0"): $*" >&2; exit 1; }

ua_setup_apt() {
  UA_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/grokbot-nas/apt-$APP_PKG"
  UA_OPTS=(
    -o Dir::Etc::SourceList=/dev/null
    -o "Dir::Etc::SourceParts=$UA_STATE/sources.d"
    -o Dir::Etc::Preferences=/dev/null
    -o "Dir::Etc::PreferencesParts=$UA_STATE/empty"
    -o "Dir::State::Lists=$UA_STATE/lists"
    -o "Dir::Cache=$UA_STATE/cache"
    -o "Dir::Cache::Archives=$UA_STATE/cache/archives"
    -o Dir::State::status=/dev/null
    -o "APT::Sandbox::User=$(id -un 2>/dev/null || id -u)"
    -o Debug::NoLocking=1
  )
  [ -r "$REPO_KEY" ] || ua_die "missing signing key $REPO_KEY"
  mkdir -p "$UA_STATE/sources.d" "$UA_STATE/empty" "$UA_STATE/lists/partial" \
           "$UA_STATE/cache/archives/partial"
  # apt reads this file first. It skips the system apt.conf.d hooks, which
  # write to /var.
  export APT_CONFIG="$UA_STATE/apt.conf"
  echo "Dir::Etc::Parts \"$UA_STATE/empty\";" > "$APT_CONFIG"
  cat > "$UA_STATE/sources.d/$APP_PKG.sources" <<EOF
Types: deb
URIs: $REPO_URL
Suites: $REPO_SUITE
Components: $REPO_COMPONENT
Architectures: $(dpkg --print-architecture)
Signed-By: $REPO_KEY
EOF
}

ua_latest() {
  apt-get "${UA_OPTS[@]}" -qq update >&2 || return 1
  apt-cache "${UA_OPTS[@]}" policy "$APP_PKG" | awk '/Candidate:/ {print $2}'
}

ua_installed() {
  [ -L "$APP_ROOT/current" ] && [ -x "$APP_ROOT/current/$APP_BIN" ] || return 0
  basename "$(readlink "$APP_ROOT/current")"
}

# Write a .desktop file from the package's one, with our launcher and icon.
#   ua_desktop_file <source .desktop> <launcher> <icon> [set-scheme-defaults]
ua_desktop_file() {
  local src="$1" dst m
  dst="$APPS/$(basename "$1")"
  [ -f "$src" ] || ua_die "the package has no $(basename "$src")"
  mkdir -p "$APPS"
  sed -e "s|^Exec=[^ ]*|Exec=$2|" -e "s|^Icon=.*|Icon=$3|" "$src" > "$dst"
  if [ "${4:-}" = set-scheme-defaults ]; then
    for m in $(sed -n 's/^MimeType=//p' "$dst" | tr ';' ' '); do
      xdg-mime default "$(basename "$dst")" "$m" \
        || echo "warning: cannot set the $m handler" >&2
    done
  fi
  update-desktop-database "$APPS" 2>/dev/null || true
}

ua_prune() {  # keep the current and the newest earlier version
  local current others=() d
  current="$(ua_installed)"
  while IFS= read -r d; do
    [ "$d" = "$current" ] || others+=("$d")
  done < <(find "$APP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort -V -r)
  for d in "${others[@]:1}"; do rm -rf "${APP_ROOT:?}/$d"; done
}

ua_install() {
  local latest current tmp deb
  latest="$(ua_latest)" || ua_die "cannot read the $APP_TITLE repository ($REPO_URL)"
  [[ "$latest" =~ ^[0-9][0-9A-Za-z.+~-]*$ ]] || ua_die "unexpected version '$latest'"
  current="$(ua_installed)"
  if [ "$current" = "$latest" ] && [ "${UA_FORCE:-0}" != 1 ]; then
    echo "$APP_TITLE $current is up to date."
    return 0
  fi
  echo "Installing $APP_TITLE $latest${current:+ (was $current)} into $APP_ROOT ..."

  tmp="$(mktemp -d "$APP_ROOT/.tmp.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  (cd "$tmp" && apt-get "${UA_OPTS[@]}" download "$APP_PKG=$latest")
  deb="$(find "$tmp" -maxdepth 1 -name "${APP_PKG}_*.deb" -print -quit)"
  [ -n "$deb" ] || ua_die "download failed"
  [ "$(dpkg-deb -f "$deb" Package)" = "$APP_PKG" ] || ua_die "wrong package in $deb"
  [ "$(dpkg-deb -f "$deb" Version)" = "$latest" ] || ua_die "wrong version in $deb"

  dpkg-deb -x "$deb" "$tmp/x"
  rm -rf "${APP_ROOT:?}/$latest"
  app_unpack "$tmp/x" "$APP_ROOT/$latest"
  [ -x "$APP_ROOT/$latest/$APP_BIN" ] || ua_die "unexpected package layout"

  # Switch with one rename, so a running app never sees a half install.
  ln -sfn "$latest" "$APP_ROOT/.current.new"
  mv -T "$APP_ROOT/.current.new" "$APP_ROOT/current"
  app_register "$tmp/x"
  rm -rf "$tmp"
  trap - EXIT
  ua_prune
  echo "$APP_TITLE $latest is installed."
}

ua_usage() {
  local me
  me="$(basename "$0")"
  cat <<EOF
Install or update $APP_TITLE into $APP_ROOT.

  $me            install the newest version, or update to it
  $me --check    exit 0: current, 10: update available, 11: not installed
  $me --force    install the newest version again
  $me --remove   remove the app (your $APP_TITLE data stays)
EOF
}

ua_main() {
  case "${1:-}" in
    "" | --check | --force | --remove) ;;
    -h | --help) ua_usage; exit 0 ;;
    *) ua_die "unknown option '$1' (try --help)" ;;
  esac

  mkdir -p "$APP_ROOT"
  exec 9> "$APP_ROOT/.lock"
  flock -n 9 || ua_die "another install of $APP_TITLE is running"

  case "${1:-}" in
    --remove)
      rm -rf "${APP_ROOT:?}" "${XDG_CACHE_HOME:-$HOME/.cache}/grokbot-nas/apt-$APP_PKG"
      app_unregister
      echo "$APP_TITLE is removed. Its data in \"$APP_DATA\" is kept."
      ;;
    --check)
      local latest current
      ua_setup_apt
      latest="$(ua_latest)" || exit 1
      current="$(ua_installed)"
      if [ -z "$current" ]; then echo "not installed (latest: $latest)"; exit 11; fi
      if [ "$current" != "$latest" ]; then echo "update available: $current -> $latest"; exit 10; fi
      echo "up to date: $current"
      ;;
    *)
      [ "${1:-}" = --force ] && UA_FORCE=1
      ua_setup_apt
      ua_install
      ;;
  esac
}
