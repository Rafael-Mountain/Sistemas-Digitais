#include <stdio.h>
#include <stdlib.h>
#include <string.h>  // Adicionado para resolver o erro de strlen

#define MAX_LINE_LENGTH 1024

// Função para pular linhas comentadas no arquivo PGM
void skip_comment(FILE *file) {
    char line[MAX_LINE_LENGTH];
    while (fgets(line, sizeof(line), file)) {
        if (line[0] != '#') {
            break;
        }
    }
    fseek(file, -strlen(line), SEEK_CUR);  // Agora a função strlen está definida corretamente
}

// Função principal
int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Uso: %s <arquivo_pgm> <arquivo_mif>\n", argv[0]);
        return 1;
    }

    FILE *pgmFile = fopen(argv[1], "rb");
    if (!pgmFile) {
        perror("Erro ao abrir o arquivo PGM");
        return 1;
    }

    // Ler o cabeçalho do PGM (verificar se é um arquivo PGM válido)
    char header[3];
    if (fread(header, 1, 3, pgmFile) != 3 || header[0] != 'P' || header[1] != '5') {
        fprintf(stderr, "Arquivo PGM inválido ou não suportado. Esperado formato P5.\n");
        fclose(pgmFile);
        return 1;
    }

    // Ignorar possíveis comentários
    skip_comment(pgmFile);

    // Ler largura, altura e valor máximo do pixel
    int width, height, maxval;
    if (fscanf(pgmFile, "%d %d", &width, &height) != 2) {
        fprintf(stderr, "Erro ao ler as dimensões da imagem.\n");
        fclose(pgmFile);
        return 1;
    }

    skip_comment(pgmFile); // Ignorar linha de comentário

    if (fscanf(pgmFile, "%d", &maxval) != 1) {
        fprintf(stderr, "Erro ao ler o valor máximo do pixel.\n");
        fclose(pgmFile);
        return 1;
    }

    if (maxval > 255) {
        fprintf(stderr, "Valor máximo do pixel deve ser 255.\n");
        fclose(pgmFile);
        return 1;
    }

    // Abrir o arquivo MIF para escrever
    FILE *mifFile = fopen(argv[2], "w");
    if (!mifFile) {
        perror("Erro ao abrir o arquivo MIF");
        fclose(pgmFile);
        return 1;
    }

    // Escrever o cabeçalho do arquivo MIF
    fprintf(mifFile, "DEPTH = %d;\n", width * height);
    fprintf(mifFile, "WIDTH = 8;\n"); // Cada valor de pixel tem 8 bits (1 byte)
    fprintf(mifFile, "ADDRESS_RADIX = DEC;\n");
    fprintf(mifFile, "DATA_RADIX = HEX;\n");
    fprintf(mifFile, "CONTENT\n");
    fprintf(mifFile, "BEGIN\n");

    // Ler os pixels e escrever no arquivo MIF
    unsigned char pixel;
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            if (fread(&pixel, 1, 1, pgmFile) != 1) {
                fprintf(stderr, "Erro ao ler o pixel na posição (%d, %d)\n", i, j);
                fclose(pgmFile);
                fclose(mifFile);
                return 1;
            }
            fprintf(mifFile, "%d : %02X;\n", i * width + j, pixel);
        }
    }

    // Fechar os arquivos
    fprintf(mifFile, "END;\n");
    fclose(pgmFile);
    fclose(mifFile);

    printf("Conversão concluída com sucesso!\n");
    return 0;
}

