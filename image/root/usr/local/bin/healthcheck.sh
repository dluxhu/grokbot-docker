#!/bin/bash
# Healthy when the desktop answers, and each enabled terminal door answers.
# Any HTTP status counts (basic auth gives 401).
code="$(curl -sk -o /dev/null -w '%{http_code}' "https://localhost:${CUSTOM_HTTPS_PORT:-3001}/")"
[ "$code" != "000" ] || exit 1

if [ "${TTYD:-0}" = "1" ]; then
  curl -s -o /dev/null http://localhost:7681 || exit 1
fi

if [ "${SSHD:-0}" = "1" ]; then
  exec 3<> /dev/tcp/127.0.0.1/2222 && head -c 4 <&3 | grep -q SSH || exit 1
fi

exit 0
