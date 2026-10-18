# Login shells (ssh) get the same agent paths as the container environment.
export NPM_CONFIG_PREFIX=/config/.npm-global
export PIP_BREAK_SYSTEM_PACKAGES=1
export BROWSER=grokbot-open-url
case ":${PATH}:" in
  *":/config/.local/bin:"*) ;;
  *) PATH="/config/.local/bin:/config/.npm-global/bin:${PATH}" ;;
esac
export PATH
