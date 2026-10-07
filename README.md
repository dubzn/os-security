# TP2 Seguridad en Sistemas Operativos

Grupo 2 — Sistemas Operativos y Redes II, UNGS.

El trabajo se realiza **solo en una VM Ubuntu Server 24.04 LTS amd64**. La carpeta `codigo_base/` conserva el material provisto para el TP y las implementaciones se agregan junto a sus plantillas:

- Parte 1: `codigo_base/hardening/hardening.sh`.
- Parte 2: perfil AppArmor pendiente de incorporar por el compañero responsable.
- Parte 3: `codigo_base/audit/99-tp2.rules` y `codigo_base/aide/aide.conf`.

El informe Word en `informe/TP2_seguridad_SO_borrador.docx` es una copia de trabajo del [documento compartido](https://docs.google.com/document/d/1PxNypBsW1a1rSgI-hDZHKyqj88GxaVyOjeQ6kbqVa58/edit). Conserva las capturas de la Parte 2. Faltan el escenario integrador, la conclusión y algunas evidencias que todavía están en la VM.

Para agregar la Parte 2, partir de la rama `master` actualizada, incorporar el perfil en `codigo_base/apparmor/`, validar en la VM y hacer un commit específico de AppArmor. No subir contraseñas, claves SSH, discos de la VM ni archivos de configuración privados del equipo personal.
