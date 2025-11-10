#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include "hps_0.h" // Header gerado pelo Platform Designer

#define LW_BRIDGE_BASE 0xFF200000
#define LW_BRIDGE_SPAN 0x00200000

// DEFINIÇÕES DA ISA (espelhando o Verilog)
#define INST_NOP            (0b000 << 29)
#define INST_ZOOM_IN        (0b001 << 29)
#define INST_ZOOM_OUT       (0b010 << 29)
#define INST_REPLICATION    (0b011 << 29)
#define INST_DECIMATION     (0b100 << 29)
#define INST_NEAREST_NEIGHBOR (0b101 << 29)
#define INST_BLOCK_AVERAGE  (0b110 << 29)

// Protótipos
void print_menu();
void send_instruction(volatile unsigned int *pio_ptr, unsigned int instruction);

int main(void) {
    volatile unsigned int *PIO_instruction_ptr;
    int fd;
    void *LW_virtual;
    int user_choice = 0;

    // Mapear a memória
    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERRO: Nao foi possivel abrir /dev/mem...\n"); return -1;
    }
    LW_virtual = mmap(NULL, LW_BRIDGE_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, LW_BRIDGE_BASE);
    if (LW_virtual == MAP_FAILED) {
        printf("ERRO: mmap() falhou...\n"); close(fd); return -1;
    }
    PIO_instruction_ptr = (unsigned int *)(LW_virtual + PIO_INSTRUCTION_BASE);
    printf("Controlador de imagem ISA v3 iniciado.\n");

    // Loop principal
    while (1) {
        print_menu();
        
        if (scanf("%d", &user_choice) != 1) {
            // Limpa o buffer de entrada se o usuário digitar um caractere
            while(getchar()!='\n'); 
            user_choice = 0; // Atribui uma opção inválida
        }

        switch (user_choice) {
            case 1: send_instruction(PIO_instruction_ptr, INST_ZOOM_IN); break;
            case 2: send_instruction(PIO_instruction_ptr, INST_ZOOM_OUT); break;
            case 3: send_instruction(PIO_instruction_ptr, INST_REPLICATION); break;
            case 4: send_instruction(PIO_instruction_ptr, INST_NEAREST_NEIGHBOR); break;
            case 5: send_instruction(PIO_instruction_ptr, INST_DECIMATION); break;
            case 6: send_instruction(PIO_instruction_ptr, INST_BLOCK_AVERAGE); break;
            case 7: printf("Saindo...\n"); goto cleanup;
            default: printf("Opcao invalida. Tente novamente.\n"); break;
        }
        sleep(1); // Pausa para o FPGA ter tempo de processar a imagem
    }

cleanup:
    // Limpeza
    munmap(LW_virtual, LW_BRIDGE_SPAN);
    close(fd);
    return 0;
}

void print_menu() {
    printf("\n--- MENU DE CONTROLE DE IMAGEM ---\n");
    printf("Acoes:\n");
    printf("  1. Zoom In\n");
    printf("  2. Zoom Out\n");
    printf("\nConfigurar Algoritmo de ZOOM IN:\n");
    printf("  3. Usar Replication\n");
    printf("  4. Usar Nearest Neighbor\n");
    printf("\nConfigurar Algoritmo de ZOOM OUT:\n");
    printf("  5. Usar Decimation\n");
    printf("  6. Usar Block Average\n");
    printf("\nSistema:\n");
    printf("  7. Sair\n");
    printf("Escolha uma opcao: ");
}

void send_instruction(volatile unsigned int *pio_ptr, unsigned int instruction) {
    printf(" -> Enviando instrucao: 0x%08X\n", instruction);
    *pio_ptr = instruction;
    usleep(1000); // Garante que o FPGA veja o valor antes de ser limpo
    *pio_ptr = INST_NOP;
    printf(" -> Instrucao enviada e PIO limpo com NOP.\n\n");
}
