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

# The check mode records its observations, but it does not create backups or
# change any security setting. All modes append to the required audit log.
if [[ "$MODE" != "--check" ]]; then
  mkdir -p "$STATE_DIR"
fi
mkdir -p "$(dirname "$LOG_FILE")"
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
  # Preserve the state before the first application, even after later reruns.
  if [[ -e "$STATE_DIR/$key.existed" || -e "$STATE_DIR/$key.absent" ]]; then
    return
  fi
  if [[ -e "$real" ]]; then
    cp -a "$real" "$STATE_DIR/$key.backup"
    : > "$STATE_DIR/$key.existed"
  else
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

file_matches() {
  local target="$1" expected="$2"
  [[ -f "$(path "$target")" ]] && cmp -s "$(path "$target")" <(printf '%s' "$expected")
}

SSH_FILE=/etc/ssh/sshd_config.d/00-tp2-root-login.conf
PW_FILE=/etc/security/pwquality.conf.d/99-tp2.conf
UMASK_FILE=/etc/profile.d/99-tp2-umask.sh
SYSCTL_FILE=/etc/sysctl.d/99-tp2-protected-links.conf

SSH_CONTENT=$'# TP2: deny direct SSH login by root.\nPermitRootLogin no\n'
PW_CONTENT=$'# TP2: bounded password quality policy.\nminlen = 12\nminclass = 3\nmaxrepeat = 3\n'
UMASK_CONTENT=$'# TP2: default mask for new login shells.\numask 027\n'
SYSCTL_CONTENT=$'# TP2: protect hard links and symbolic links.\nfs.protected_hardlinks = 1\nfs.protected_symlinks = 1\n'

ssh_effective() {
  [[ -n "$ROOT" ]] && return 0
  # Consume all sshd output: grep -q can exit early and make sshd receive
  # SIGPIPE, which pipefail would misread as a failed effective-setting check.
  sshd -T 2>/dev/null | grep -x 'permitrootlogin no' >/dev/null
}

pwquality_active() {
  local pam_file
  pam_file="$(path /etc/pam.d/common-password)"
  [[ -r "$pam_file" ]] && grep -Eq '^[[:space:]]*password[[:space:]]+.*pam_pwquality\.so' "$pam_file"
}

sysctl_effective() {
  [[ -n "$ROOT" ]] && return 0
  [[ "$(sysctl -n fs.protected_hardlinks 2>/dev/null)" == 1 &&
     "$(sysctl -n fs.protected_symlinks 2>/dev/null)" == 1 ]]
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
  case "$MODE" in
    --check)
      if file_matches "$SSH_FILE" "$SSH_CONTENT" && ssh_effective; then
        mark_checked "SSH" "Fragmento presente y PermitRootLogin efectivo en no"
      else
        mark_error "SSH" "Falta el fragmento o PermitRootLogin no es efectivo"
      fi
      ;;
    --apply)
      if file_matches "$SSH_FILE" "$SSH_CONTENT" && ssh_effective; then
        mark_skipped "SSH" "Permiso de root por SSH ya deshabilitado"
        return
      fi
      backup_file "$SSH_FILE"
      write_file "$SSH_FILE" 0644 "$SSH_CONTENT"
      if [[ -z "$ROOT" ]]; then
        if ! sshd -t; then
          restore_file "$SSH_FILE"
          mark_error "SSH" "sshd -t rechazo el fragmento; se repuso el archivo anterior"
          return
        fi
        if ! ssh_effective; then
          restore_file "$SSH_FILE"
          mark_error "SSH" "El valor efectivo no es PermitRootLogin no; revisar precedencia"
          return
        fi
        if ! systemctl reload ssh.service; then
          mark_error "SSH" "La recarga de ssh.service fallo; revisar desde la consola de la VM"
          return
        fi
      fi
      mark_applied "SSH" "Fragmento validado con sshd -t y servicio recargado"
      ;;
    --restore)
      restore_file "$SSH_FILE"
      if [[ -z "$ROOT" ]]; then
        if sshd -t; then
          systemctl reload ssh.service || mark_error "SSH" "No se pudo recargar ssh.service"
        else
          mark_error "SSH" "La configuracion restaurada no supera sshd -t"
        fi
      fi
      ;;
  esac
}

control_pwquality() {
  case "$MODE" in
    --check)
      if file_matches "$PW_FILE" "$PW_CONTENT" && pwquality_active; then
        mark_checked "PWQUALITY" "Politica presente y pam_pwquality activo"
      else
        mark_error "PWQUALITY" "Falta la politica o pam_pwquality no esta activo"
      fi
      ;;
    --apply)
      if ! pwquality_active; then
        mark_error "PWQUALITY" "pam_pwquality no aparece en common-password"
        return
      fi
      if file_matches "$PW_FILE" "$PW_CONTENT"; then
        mark_skipped "PWQUALITY" "Politica ya configurada"
        return
      fi
      backup_file "$PW_FILE"
      write_file "$PW_FILE" 0644 "$PW_CONTENT"
      mark_applied "PWQUALITY" "minlen=12, minclass=3 y maxrepeat=3"
      ;;
    --restore)
      restore_file "$PW_FILE"
      ;;
  esac
}

control_umask() {
  case "$MODE" in
    --check)
      if file_matches "$UMASK_FILE" "$UMASK_CONTENT"; then
        mark_checked "UMASK" "Fragmento umask 027 presente; validar en una nueva sesion"
      else
        mark_error "UMASK" "Falta fragmento de umask 027"
      fi
      ;;
    --apply)
      if file_matches "$UMASK_FILE" "$UMASK_CONTENT"; then
        mark_skipped "UMASK" "Fragmento ya configurado"
        return
      fi
      backup_file "$UMASK_FILE"
      write_file "$UMASK_FILE" 0644 "$UMASK_CONTENT"
      mark_applied "UMASK" "umask 027 configurada para nuevas sesiones"
      ;;
    --restore)
      restore_file "$UMASK_FILE"
      ;;
  esac
}

control_sysctl() {
  case "$MODE" in
    --check)
      if file_matches "$SYSCTL_FILE" "$SYSCTL_CONTENT" && sysctl_effective; then
        mark_checked "SYSCTL" "Fragmento persistente y valores efectivos en 1"
      else
        mark_error "SYSCTL" "Falta fragmento o los valores efectivos no son 1"
      fi
      ;;
    --apply)
      if file_matches "$SYSCTL_FILE" "$SYSCTL_CONTENT" && sysctl_effective; then
        mark_skipped "SYSCTL" "Enlaces protegidos ya configurados"
        return
      fi
      if [[ -z "$ROOT" && ! -f "$STATE_DIR/sysctl.previous" ]]; then
        if ! { sysctl -n fs.protected_hardlinks && sysctl -n fs.protected_symlinks; } > "$STATE_DIR/sysctl.previous"; then
          mark_error "SYSCTL" "No se pudieron guardar los valores anteriores"
          return
        fi
      fi
      backup_file "$SYSCTL_FILE"
      write_file "$SYSCTL_FILE" 0644 "$SYSCTL_CONTENT"
      if [[ -z "$ROOT" ]]; then
        if ! sysctl -p "$(path "$SYSCTL_FILE")" || ! sysctl_effective; then
          restore_file "$SYSCTL_FILE"
          if [[ -f "$STATE_DIR/sysctl.previous" ]]; then
            local old_values=()
            mapfile -t old_values < "$STATE_DIR/sysctl.previous"
            if [[ ${#old_values[@]} -eq 2 ]]; then
              sysctl -w "fs.protected_hardlinks=${old_values[0]}" \
                        "fs.protected_symlinks=${old_values[1]}" >/dev/null || true
            fi
          fi
          mark_error "SYSCTL" "No se aplicaron los valores esperados"
          return
        fi
      fi
      mark_applied "SYSCTL" "Enlaces protegidos persistidos y efectivos"
      ;;
    --restore)
      restore_file "$SYSCTL_FILE"
      if [[ -z "$ROOT" && -f "$STATE_DIR/sysctl.previous" ]]; then
        local old_values=()
        mapfile -t old_values < "$STATE_DIR/sysctl.previous"
        if [[ ${#old_values[@]} -eq 2 ]]; then
          sysctl -w "fs.protected_hardlinks=${old_values[0]}" \
                    "fs.protected_symlinks=${old_values[1]}" >/dev/null \
            || mark_error "SYSCTL" "No se pudieron restaurar los valores anteriores"
        else
          mark_error "SYSCTL" "Respaldo de valores anteriores incompleto"
        fi
      fi
      ;;
  esac
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
