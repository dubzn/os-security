#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-}"
ROOT="${TP2_ROOT:-}"
STATE_DIR="${TP2_STATE_DIR:-${ROOT}/var/lib/tp2-hardening}"
LOG_FILE="${TP2_LOG_FILE:-${ROOT}/var/log/tp2-hardening.log}"
APPLIED=0
SKIPPED=0
CHECKED=0
ERRORS=0

usage() {
  cat <<'USAGE'
Uso: sudo ./hardening.sh --check | --apply | --restore

Variables para pruebas aisladas:
  TP2_ROOT=/ruta/raiz-ficticia
  TP2_STATE_DIR=/ruta/estado
  TP2_LOG_FILE=/ruta/log
USAGE
}

if [[ "$MODE" != "--check" && "$MODE" != "--apply" && "$MODE" != "--restore" ]]; then
  usage
  exit 2
fi

if [[ -z "$ROOT" && ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: para modificar el sistema real debe ejecutar el script con sudo." >&2
  exit 3
fi

path() { printf '%s%s' "$ROOT" "$1"; }

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 0600 "$LOG_FILE" 2>/dev/null || true

log() {
  local level="$1" control="$2" message="$3"
  printf '%s [%s] [%s] %s\n' "$(date -Iseconds)" "$level" "$control" "$message" | tee -a "$LOG_FILE"
}

mark_applied() { APPLIED=$((APPLIED + 1)); log "APPLIED" "$1" "$2"; }
mark_skipped() { SKIPPED=$((SKIPPED + 1)); log "SKIPPED" "$1" "$2"; }
mark_checked() { CHECKED=$((CHECKED + 1)); log "CHECK" "$1" "$2"; }
mark_error() { ERRORS=$((ERRORS + 1)); log "ERROR" "$1" "$2"; }

backup_key() { printf '%s' "$1" | sed 's#/#__#g'; }

backup_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$real" && ! -e "$STATE_DIR/$key.existed" ]]; then
    cp -a "$real" "$STATE_DIR/$key.backup"
    : > "$STATE_DIR/$key.existed"
  elif [[ ! -e "$real" && ! -e "$STATE_DIR/$key.absent" ]]; then
    : > "$STATE_DIR/$key.absent"
  fi
}

restore_file() {
  local target="$1" real key
  real="$(path "$target")"
  key="$(backup_key "$target")"
  if [[ -e "$STATE_DIR/$key.existed" ]]; then
    mkdir -p "$(dirname "$real")"
    cp -a "$STATE_DIR/$key.backup" "$real"
    mark_applied "RESTORE" "Restaurado $target"
  elif [[ -e "$STATE_DIR/$key.absent" ]]; then
    rm -f "$real"
    mark_applied "RESTORE" "Eliminado $target porque no existia antes del TP"
  else
    mark_skipped "RESTORE" "Sin respaldo registrado para $target"
  fi
}

write_file() {
  local target="$1" mode="$2" content="$3" real tmp
  real="$(path "$target")"
  mkdir -p "$(dirname "$real")"
  tmp="$(mktemp "$(dirname "$real")/.tp2.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$real"
}

control_uid0() {
  local passwd_file
  passwd_file="$(path /etc/passwd)"
  if [[ ! -r "$passwd_file" ]]; then
    mark_error "UID0" "No se puede leer /etc/passwd"
    return
  fi
  local extra
  extra="$(awk -F: '$3 == 0 && $1 != "root" {print $1}' "$passwd_file" | paste -sd, -)"
  if [[ -n "$extra" ]]; then
    mark_error "UID0" "Cuentas adicionales con UID 0: $extra. No se corrigen automaticamente."
  else
    mark_checked "UID0" "Solo root posee UID 0"
  fi
}

control_ssh() {
  # TODO: implementar este control con las funciones auxiliares provistas.
  # Debe respetar --check, --apply y --restore, y registrar el resultado.
  mark_error "TODO" "Funcion control_ssh pendiente de implementar"
}

control_pwquality() {
  # TODO: implementar este control con las funciones auxiliares provistas.
  # Debe respetar --check, --apply y --restore, y registrar el resultado.
  mark_error "TODO" "Funcion control_pwquality pendiente de implementar"
}

control_umask() {
  # TODO: implementar este control con las funciones auxiliares provistas.
  # Debe respetar --check, --apply y --restore, y registrar el resultado.
  mark_error "TODO" "Funcion control_umask pendiente de implementar"
}

control_sysctl() {
  # TODO: implementar este control con las funciones auxiliares provistas.
  # Debe respetar --check, --apply y --restore, y registrar el resultado.
  mark_error "TODO" "Funcion control_sysctl pendiente de implementar"
}

control_uid0
control_ssh
control_pwquality
control_umask
control_sysctl

log "RESUMEN" "TP2" "Aplicados=$APPLIED Omitidos=$SKIPPED Verificados=$CHECKED Errores=$ERRORS"

if (( ERRORS > 0 )); then
  exit 1
fi
