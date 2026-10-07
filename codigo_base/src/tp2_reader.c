#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int print_file(const char *path) {
    FILE *fp = fopen(path, "r");
    if (fp == NULL) {
        fprintf(stderr, "tp2-reader: no se pudo abrir '%s': %s\n", path, strerror(errno));
        return 2;
    }

    char buffer[512];
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        fputs(buffer, stdout);
    }

    if (ferror(fp)) {
        fprintf(stderr, "tp2-reader: error de lectura en '%s'\n", path);
        fclose(fp);
        return 3;
    }

    if (fclose(fp) != 0) {
        fprintf(stderr, "tp2-reader: no se pudo cerrar '%s': %s\n", path, strerror(errno));
        return 4;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Uso: %s ARCHIVO\n", argv[0]);
        return 1;
    }
    return print_file(argv[1]);
}
