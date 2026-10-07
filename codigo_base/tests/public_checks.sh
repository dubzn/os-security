#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---estructura}"
fails=0

ok() { echo "[OK] $1"; }
fail() { echo "[FALLO] $1" >&2; fails=$((fails + 1)); }

check_file() {
  if [[ -f "$1" ]]; then
    ok "Existe ${1#"$ROOT_DIR"/}"
  else
    fail "Falta ${1#"$ROOT_DIR"/}"
  fi
}

case "$MODE" in
  --estructura|--entorno|--entrega) ;;
  *)
    cat <<'USAGE'
Uso: ./tests/public_checks.sh [--estructura | --entorno | --entrega]

  --estructura  (por defecto) Verifica que el material provisto este completo
                y que todo compile. Usela durante el desarrollo del TP.
  --entorno     Ademas verifica la VM preparada: requiere sudo. Usela en la
                Parte 0, despues de ejecutar scripts/preparar_entorno.sh.
  --entrega     Ademas verifica que los cuatro entregables esten completos.
                Usela antes de armar el ZIP del grupo.
USAGE
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# 1. Material provisto por la catedra. Estos archivos no deben eliminarse.
# ---------------------------------------------------------------------------
for f in \
  "$ROOT_DIR/Makefile" \
  "$ROOT_DIR/src/tp2_reader.c" \
  "$ROOT_DIR/src/tp2_event.c" \
  "$ROOT_DIR/hardening/hardening_base.sh" \
  "$ROOT_DIR/apparmor/usr.local.bin.tp2-reader.base" \
  "$ROOT_DIR/audit/99-tp2.rules.base" \
  "$ROOT_DIR/aide/aide.conf.base"; do
  check_file "$f"
done

bash -n "$ROOT_DIR/hardening/hardening_base.sh" && ok "Sintaxis Bash de la plantilla de hardening" || fail "Sintaxis Bash invalida"
bash -n "$ROOT_DIR/scripts/preparar_entorno.sh" && ok "Sintaxis del preparador" || fail "Preparador invalido"
bash -n "$ROOT_DIR/scripts/escenario_final.sh" && ok "Sintaxis del escenario final" || fail "Escenario final invalido"

make -C "$ROOT_DIR" clean all >/dev/null 2>&1 && ok "Compilacion C11 estricta" || fail "La compilacion fallo"

# ---------------------------------------------------------------------------
# 2. Entregables del grupo. Solo se exigen en modo --entrega.
# ---------------------------------------------------------------------------
ENTREGABLES=(
  "$ROOT_DIR/hardening/hardening.sh"
  "$ROOT_DIR/apparmor/usr.local.bin.tp2-reader"
  "$ROOT_DIR/audit/99-tp2.rules"
  "$ROOT_DIR/aide/aide.conf"
)

if [[ "$MODE" == "--entrega" ]]; then
  for f in "${ENTREGABLES[@]}"; do
    check_file "$f"
  done
  if [[ -f "$ROOT_DIR/hardening/hardening.sh" ]]; then
    bash -n "$ROOT_DIR/hardening/hardening.sh" && ok "Sintaxis Bash de hardening.sh" || fail "hardening.sh tiene errores de sintaxis"
  fi
fi

# Bloques TODO pendientes. Se excluyen las plantillas provistas por la catedra,
# que conservan sus TODO de forma intencional y no deben modificarse.
if grep -R -n --exclude='*.base' --exclude='hardening_base.sh' 'TODO' \
     "$ROOT_DIR/hardening" "$ROOT_DIR/apparmor" "$ROOT_DIR/audit" "$ROOT_DIR/aide" >/tmp/tp2_todos.txt 2>/dev/null; then
  fail "Quedan bloques TODO sin resolver:"
  cat /tmp/tp2_todos.txt >&2
else
  ok "No quedan TODO en los entregables"
fi

# ---------------------------------------------------------------------------
# 3. Estado de la maquina virtual. Solo en modo --entorno.
# ---------------------------------------------------------------------------
if [[ "$MODE" == "--entorno" ]]; then
  [[ ${EUID:-$(id -u)} -eq 0 ]] || fail "Ejecute este modo con sudo"
  for d in /srv/tp2/datos /srv/tp2/config /srv/tp2/aide /srv/tp2/evidencias; do
    [[ -d "$d" ]] && ok "Existe $d" || fail "Falta $d. Ejecute scripts/preparar_entorno.sh"
  done
  for b in /usr/local/bin/tp2-reader /usr/local/bin/tp2-event; do
    [[ -x "$b" ]] && ok "Instalado $b" || fail "Falta $b"
  done
  command -v aa-status >/dev/null && aa-status --enabled 2>/dev/null && ok "AppArmor habilitado" || fail "AppArmor no esta habilitado"
  systemctl is-active --quiet auditd 2>/dev/null && ok "auditd activo" || fail "auditd no esta activo"
  command -v aide >/dev/null && ok "AIDE instalado" || fail "AIDE no esta instalado"

  # Estos artefactos solo existen una vez completadas las Partes 2 y 3.
  if [[ -f "$ROOT_DIR/apparmor/usr.local.bin.tp2-reader" ]]; then
    apparmor_parser -Q "$ROOT_DIR/apparmor/usr.local.bin.tp2-reader" >/dev/null 2>&1 \
      && ok "Sintaxis del perfil AppArmor" || fail "El perfil AppArmor no es valido"
  fi
  if [[ -f "$ROOT_DIR/aide/aide.conf" ]]; then
    aide --config="$ROOT_DIR/aide/aide.conf" --config-check >/dev/null 2>&1 \
      && ok "Sintaxis de aide.conf" || fail "aide.conf no es valido"
  fi
fi

if (( fails > 0 )); then
  printf '\nResultado: %d comprobaciones fallaron.\n' "$fails" >&2
  exit 1
fi
echo
echo "Resultado: comprobaciones publicas superadas."
