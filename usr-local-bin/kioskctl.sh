#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  kioskctl set-url <https://your-site>
  kioskctl set-browser <auto|chromium|firefox>
  kioskctl show
USAGE
}

case "${1:-}" in
  set-url)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    echo "$2" > /etc/kiosk/url.conf
    systemctl restart kiosk-browser.service || true
    echo "URL set to: $2"
    ;;
  set-browser)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    case "$2" in
      auto|chromium|firefox) ;;
      *)
        echo "Browser must be: auto, chromium, or firefox" >&2
        exit 1
        ;;
    esac
    echo "$2" > /etc/kiosk/browser.conf
    systemctl restart kiosk-browser.service || true
    echo "Browser preference set to: $2"
    ;;
  show)
    echo -n "URL: "
    cat /etc/kiosk/url.conf 2>/dev/null || echo "(not set)"
    echo -n "Browser: "
    cat /etc/kiosk/browser.conf 2>/dev/null || echo "auto"
    ;;
  *)
    usage
    exit 1
    ;;
esac
