#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static void iso8601_now(char *buf, size_t size) {
    time_t now = time(NULL);
    struct tm tm_value;
    if (localtime_r(&now, &tm_value) == NULL) {
        snprintf(buf, size, "fecha-desconocida");
        return;
    }
    if (strftime(buf, size, "%Y-%m-%dT%H:%M:%S%z", &tm_value) == 0) {
        snprintf(buf, size, "fecha-desconocida");
    }
}

int main(int argc, char **argv) {
    const char *message = argc > 1 ? argv[1] : "evento sin mensaje";
    const char *path = "/srv/tp2/datos/eventos.log";
    FILE *fp = fopen(path, "a");
    if (fp == NULL) {
        fprintf(stderr, "tp2-event: no se pudo abrir '%s': %s\n", path, strerror(errno));
        return 2;
    }

    char timestamp[64];
    iso8601_now(timestamp, sizeof(timestamp));
    if (fprintf(fp, "%s pid=%ld uid=%ld mensaje=%s\n", timestamp,
                (long)getpid(), (long)getuid(), message) < 0) {
        fprintf(stderr, "tp2-event: error al escribir '%s'\n", path);
        fclose(fp);
        return 3;
    }

    if (fclose(fp) != 0) {
        fprintf(stderr, "tp2-event: no se pudo cerrar '%s': %s\n", path, strerror(errno));
        return 4;
    }

    printf("Evento registrado en %s\n", path);
    return 0;
}
