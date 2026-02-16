#!/usr/bin/env bash
set -euo pipefail

URL_FILE="/etc/kiosk/url.conf"
BROWSER_FILE="/etc/kiosk/browser.conf"
URL="https://example.com"
BROWSER_PREF="auto"

[[ -f "${URL_FILE}" ]] && URL="$(head -n1 "${URL_FILE}" | tr -d '\r')"
[[ -f "${BROWSER_FILE}" ]] && BROWSER_PREF="$(head -n1 "${BROWSER_FILE}" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"

run_chromium() {
  exec chromium-browser \
    --kiosk \
    --incognito \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    --overscroll-history-navigation=0 \
    "${URL}"
}

run_firefox() {
  exec firefox-esr --kiosk "${URL}"
}

case "${BROWSER_PREF}" in
  chromium)
    command -v chromium-browser >/dev/null && run_chromium
    ;;
  firefox)
    command -v firefox-esr >/dev/null && run_firefox
    ;;
  auto)
    if command -v chromium-browser >/dev/null; then
      run_chromium
    elif command -v firefox-esr >/dev/null; then
      run_firefox
    fi
    ;;
esac

echo "No supported browser found. Install chromium-browser or firefox-esr." >&2
exit 1
