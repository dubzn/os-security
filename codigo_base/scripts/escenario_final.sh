#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: ejecute este escenario con sudo." >&2
  exit 3
fi

EVIDENCE_DIR=/srv/tp2/evidencias
mkdir -p "$EVIDENCE_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"

{
  echo "=== 1. Lectura publica ==="
  /usr/local/bin/tp2-reader /srv/tp2/datos/publico.txt || true
  echo
  echo "=== 2. Intento sobre recurso confidencial ==="
  /usr/local/bin/tp2-reader /srv/tp2/datos/confidencial.txt || true
  echo
  echo "=== 3. Evento controlado ==="
  /usr/local/bin/tp2-event "escenario_integrador_$STAMP"
  echo
  echo "=== 4. Cambio controlado de integridad ==="
  printf 'cambio integrador %s\n' "$STAMP" >> /srv/tp2/datos/publico.txt
  chmod 0640 /srv/tp2/datos/publico.txt
} 2>&1 | tee "$EVIDENCE_DIR/escenario_$STAMP.txt"

echo "Escenario ejecutado. Reuna ahora evidencia de AppArmor, auditd y AIDE."
