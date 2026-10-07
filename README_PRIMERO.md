# TP2 - Seguridad en Sistemas Operativos

Este paquete contiene la consigna y el codigo base del TP2 de Sistemas Operativos y Redes II.

## Entorno oficial

- Ubuntu Server 24.04 LTS amd64.
- Maquina virtual aislada.
- Snapshot obligatorio antes de aplicar cambios.
- Trabajo grupal con defensa oral individual.

## Orden recomendado

1. Leer la consigna completa.
2. Crear la VM y el snapshot inicial.
3. Ejecutar `sudo ./scripts/preparar_entorno.sh --install-packages` desde `codigo_base`.
4. Ejecutar `sudo ./tests/public_checks.sh --entorno` para confirmar que la VM quedo lista.
5. Completar el hardening, el perfil AppArmor, las reglas auditd y la configuracion AIDE.
6. Guardar evidencia despues de cada etapa.
7. Ejecutar el escenario integrador.
8. Ejecutar `./tests/public_checks.sh --entrega` antes de armar el ZIP del grupo.
9. Preparar el informe y la defensa.

## Comprobaciones publicas

El script `tests/public_checks.sh` admite tres modos:

- `--estructura` (por defecto): verifica el material provisto y la compilacion.
- `--entorno`: agrega la verificacion de la VM preparada. Requiere `sudo`.
- `--entrega`: agrega la verificacion de los cuatro entregables completos.

Los archivos terminados en `.base` y `hardening_base.sh` son plantillas de la
catedra: conservan sus bloques `TODO` de forma intencional y no deben
modificarse ni eliminarse. Sus versiones completas se guardan con el nombre
definitivo indicado en la consigna.

## Importante

- No ejecute este TP sobre su equipo personal ni sobre un servidor real.
- No modifique archivos del sistema fuera de los indicados.
- Ante un error, detengase, conserve la evidencia y vuelva al snapshot si es necesario.
- Las guias y los apuntes de la catedra contienen la teoria necesaria; la documentacion oficial puede usarse para detalles operativos.
