#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: ejecute con sudo." >&2
  exit 3
fi

REMOVE_USER=0
[[ "${1:-}" == "--remove-user" ]] && REMOVE_USER=1

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -x "$BASE_DIR/hardening/hardening.sh" ]]; then
  "$BASE_DIR/hardening/hardening.sh" --restore || true
elif [[ -x "$BASE_DIR/hardening/hardening_base.sh" ]]; then
  "$BASE_DIR/hardening/hardening_base.sh" --restore || true
fi

PROFILE=/etc/apparmor.d/usr.local.bin.tp2-reader
if [[ -f "$PROFILE" ]]; then
  apparmor_parser -R "$PROFILE" 2>/dev/null || true
  rm -f "$PROFILE"
fi

rm -f /etc/audit/rules.d/99-tp2.rules
augenrules --load >/dev/null 2>&1 || true
rm -rf /srv/tp2 /var/lib/tp2-lab /var/lib/tp2-hardening
rm -f /usr/local/bin/tp2-reader /usr/local/bin/tp2-event

if (( REMOVE_USER )) && id tp2lab >/dev/null 2>&1; then
  userdel -r tp2lab 2>/dev/null || userdel tp2lab || true
fi

echo "Entorno TP2 retirado. Si necesita una restauracion exacta, vuelva al snapshot TP2_BASE."
