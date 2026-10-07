#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_PACKAGES=0
if [[ "${1:-}" == "--install-packages" ]]; then
  INSTALL_PACKAGES=1
elif [[ -n "${1:-}" ]]; then
  echo "Uso: sudo ./scripts/preparar_entorno.sh [--install-packages]" >&2
  exit 2
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 3
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR=/var/lib/tp2-lab
LAB_DIR=/srv/tp2
LAB_USER=tp2lab

log() { printf '[TP2] %s\n' "$*"; }
warn() { printf '[TP2][ADVERTENCIA] %s\n' "$*" >&2; }

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    warn "Entorno detectado: ${PRETTY_NAME:-desconocido}. La ruta oficial del TP es Ubuntu Server 24.04 LTS."
  fi
fi

if (( INSTALL_PACKAGES )); then
  log "Instalando dependencias oficiales del laboratorio..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y build-essential apparmor-utils auditd aide strace libpam-pwquality openssh-server
fi

required=(cc make apparmor_parser aa-status auditctl ausearch augenrules aide strace sshd)
missing=()
for cmd in "${required[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if (( ${#missing[@]} > 0 )); then
  printf 'Faltan herramientas: %s\n' "${missing[*]}" >&2
  echo "Ejecute nuevamente con --install-packages o instale los paquetes indicados en la consigna." >&2
  exit 4
fi

if ! aa-status 2>/dev/null | grep -q 'apparmor module is loaded'; then
  warn "AppArmor no aparece cargado. No continue con la Parte 2 hasta habilitarlo y reiniciar la VM."
fi

mkdir -p "$STATE_DIR" "$LAB_DIR"/{datos,evidencias,aide,config}
chmod 0755 "$LAB_DIR" "$LAB_DIR/datos" "$LAB_DIR/evidencias" "$LAB_DIR/aide" "$LAB_DIR/config"

if ! id "$LAB_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$LAB_USER"
  passwd -l "$LAB_USER" >/dev/null 2>&1 || true
  log "Creado usuario de laboratorio $LAB_USER (cuenta bloqueada para inicio de sesion por contrasena)."
else
  log "El usuario $LAB_USER ya existe."
fi

cat > "$LAB_DIR/datos/publico.txt" <<'DATA'
Este archivo puede ser leido por la aplicacion de prueba.
DATA
cat > "$LAB_DIR/datos/confidencial.txt" <<'DATA'
RECURSO CONTROLADO DEL TP2. No contiene informacion real.
DATA
: > "$LAB_DIR/datos/eventos.log"
chown -R root:root "$LAB_DIR"
chmod 0644 "$LAB_DIR/datos/publico.txt" "$LAB_DIR/datos/confidencial.txt" "$LAB_DIR/datos/eventos.log"

log "Compilando aplicaciones controladas..."
make -C "$ROOT_DIR" clean all
make -C "$ROOT_DIR" install

cat > "$STATE_DIR/baseline.txt" <<BASE
fecha=$(date -Iseconds)
host=$(hostname)
kernel=$(uname -r)
os=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null || true)
apparmor=$(aa-status 2>&1 | head -n 3 | tr '\n' '; ')
audit_status=$(auditctl -s 2>&1 | tr '\n' '; ')
BASE
chmod 0600 "$STATE_DIR/baseline.txt"

systemctl enable --now auditd.service >/dev/null 2>&1 || warn "No se pudo iniciar auditd automaticamente; verifique systemctl status auditd."

log "Entorno preparado. Pruebas iniciales:"
/usr/local/bin/tp2-reader "$LAB_DIR/datos/publico.txt"
/usr/local/bin/tp2-reader "$LAB_DIR/datos/confidencial.txt"
/usr/local/bin/tp2-event "preparacion inicial"

cat <<'NEXT'

Preparacion completada.
1. Cree ahora un snapshot de la VM llamado "TP2_BASE".
2. Guarde /var/lib/tp2-lab/baseline.txt como evidencia.
3. Ejecute: ./tests/public_checks.sh --entorno
4. No avance si AppArmor o auditd no estan activos.
NEXT
