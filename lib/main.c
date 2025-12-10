#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <sys/mman.h>
#include <stdint.h>
#include <math.h> 
#include <termios.h> 
#include "lib_fpga.h"

// ============================================================================
// ESTILOS E CORES (ANSI)
// ============================================================================
#define C_RESET  "\033[0m"
#define C_BOLD   "\033[1m"
#define C_RED    "\033[31m"
#define C_GREEN  "\033[32m"
#define C_YELLOW "\033[33m"
#define C_BLUE   "\033[34m"
#define C_MAGENTA "\033[35m"
#define C_CYAN   "\033[36m"
#define C_WHITE  "\033[37m"
#define BG_BLUE  "\033[44m"

// ============================================================================
// CONFIGURAÇÕES GERAIS
// ============================================================================
#define BASE_WIDTH  160
#define BASE_HEIGHT 120
#define MAX_BUFFER  (160 * 120)
#define HEADER_SIZE 15

// Ajuste de tempos:
#define HARDWARE_DELAY 30000   
#define MOVE_STEP      4       

#define MOUSE_DEV "/dev/input/event0" 

// ============================================================================
// VARIÁVEIS GLOBAIS
// ============================================================================
static unsigned char img_clean_backup[MAX_BUFFER]; 

int sel_x1 = 0, sel_y1 = 0;
int sel_x2 = BASE_WIDTH, sel_y2 = BASE_HEIGHT;
int current_zoom_level = 1;

// ============================================================================
// CONTROLE DE TERMINAL E INPUT
// ============================================================================
struct termios orig_termios;

void enable_raw_mode() {
    tcgetattr(STDIN_FILENO, &orig_termios);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void disable_raw_mode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

void clear_input_buffer() {
    int c;
    while ((c = getchar()) != '\n' && c != EOF);
}

// NOVA FUNÇÃO: Validação de entrada robusta
int get_validated_input(int min, int max) {
    int value;
    while (1) {
        if (scanf("%d", &value) == 1) {
            // Verifica se está dentro do range
            if (value >= min && value <= max) {
                clear_input_buffer(); // Limpa o \n restante
                return value;
            }
        } else {
            // Se scanf falhar (ex: digitou letra), limpa o buffer
            clear_input_buffer();
        }
        printf(C_RED "   [!] Opção inválida. Digite um valor entre %d e %d: " C_RESET, min, max);
    }
}

// ============================================================================
// FUNÇÕES AUXILIARES DE INTERFACE
// ============================================================================

void print_separator() {
    printf(C_BLUE "   +---------------------------------------------+\n" C_RESET);
}

void print_header() {
    printf("\033[H\033[J"); 
    printf("\n");
    printf(C_BLUE "   ╔═════════════════════════════════════════════╗\n");
    printf("   ║         " C_BOLD C_CYAN "FPGA SMART ZOOM SYSTEM" C_RESET C_BLUE "              ║\n");
    printf("   ║         " C_WHITE "Engenharia de Computação" C_RESET C_BLUE "            ║\n");
    printf("   ╚═════════════════════════════════════════════╝\n" C_RESET);
}

// ============================================================================
// FUNÇÕES DE MEMÓRIA E UPLOAD
// ============================================================================

void download_fpga_to_buffer(unsigned char *buffer, int width, int height) {
    int total = width * height;
    printf("   " C_CYAN "▼ Atualizando Backup (%d px)..." C_RESET, total);
    fflush(stdout);
    for (int i = 0; i < total; i++) {
        buffer[i] = (unsigned char)fpga_read_pixel(i);
    }
    printf(C_GREEN " [Sincronizado]\n" C_RESET);
}

void upload_buffer_to_fpga(unsigned char *buffer, int width, int height) {
    int total = width * height;
    int limit = (total > 19200) ? 19200 : total;
    printf("   " C_CYAN "▲ Enviando %d pixels..." C_RESET, limit);
    fflush(stdout);
    for (int i = 0; i < limit; i++) {
        fpga_write_pixel(i, buffer[i]);
    }
    printf(C_GREEN " [Concluido]\n" C_RESET);
}

void load_file_to_backup(const char *filename) {
    FILE *f = fopen(filename, "rb");
    if (!f) { 
        printf(C_RED "   [X] Erro ao abrir arquivo: %s\n" C_RESET, filename); 
        return; 
    }
    fseek(f, HEADER_SIZE, SEEK_SET);
    size_t lidos = fread(img_clean_backup, 1, MAX_BUFFER, f);
    if (lidos != MAX_BUFFER) printf(C_YELLOW "   [!] Aviso: Tamanho da imagem incorreto.\n" C_RESET);
    else printf(C_GREEN "   [✓] Imagem carregada: %s\n" C_RESET, filename);
    fclose(f);
    current_zoom_level = 1; 
}

void save_buffer_to_file(unsigned char *buffer, int width, int height, const char *filename) {
    FILE *f = fopen(filename, "wb");
    if (!f) return;
    fprintf(f, "P5\n%d %d\n255\n", width, height);
    fwrite(buffer, 1, width * height, f);
    fclose(f);
}

// ============================================================================
// LÓGICA DE MOVIMENTAÇÃO DA JANELA
// ============================================================================

void move_selection_window(int dx, int dy) {
    int sx = (sel_x1 < sel_x2) ? sel_x1 : sel_x2;
    int sy = (sel_y1 < sel_y2) ? sel_y1 : sel_y2;
    int width = abs(sel_x2 - sel_x1);
    int height = abs(sel_y2 - sel_y1);

    sx += dx;
    sy += dy;

    if (sx < 0) sx = 0;
    if (sy < 0) sy = 0;
    if (sx + width > BASE_WIDTH) sx = BASE_WIDTH - width;
    if (sy + height > BASE_HEIGHT) sy = BASE_HEIGHT - height;

    sel_x1 = sx;
    sel_y1 = sy;
    sel_x2 = sx + width;
    sel_y2 = sy + height;
}

// ============================================================================
// LÓGICA DE EXECUÇÃO DO ZOOM
// ============================================================================

void execute_zoom_logic(int target_level) {
    
    // Apaga a tela (ativa o blank) antes de começar a mexer na memória
    fpga_set_blank_pio(1);

    if (target_level == 1) {
        for (int i = 0; i < 19200; i++) fpga_write_pixel(i, img_clean_backup[i]);
        current_zoom_level = 1;
        
        // Acende a tela antes de sair
        fpga_set_blank_pio(0);
        return;
    }

    // 1. Restaura imagem limpa (Obrigatório antes de qualquer novo cálculo)
    for (int i = 0; i < 19200; i++) {
        fpga_write_pixel(i, img_clean_backup[i]);
    }
    
    int temp_w = 0, temp_h = 0;
    
    // 2. Comandos de Hardware com Delays Críticos
    if (target_level == 2) {
        fpga_cmd_zoom_in(); 
        temp_w = 320; temp_h = 240;
    } 
    else if (target_level == 4) {
        // Primeiro Zoom (2x)
        fpga_cmd_zoom_in(); 
        
        // Espera o hardware terminar o primeiro nível antes de pedir o segundo.
        usleep(HARDWARE_DELAY); 
        
        // Segundo Zoom (4x)
        fpga_cmd_zoom_in(); 
        temp_w = 640; temp_h = 480;
    }

    // Delay final para garantir que a memória está pronta para leitura
    usleep(HARDWARE_DELAY); 

    int sx = (sel_x1 < sel_x2) ? sel_x1 : sel_x2;
    int sy = (sel_y1 < sel_y2) ? sel_y1 : sel_y2;
    int ex = (sel_x1 > sel_x2) ? sel_x1 : sel_x2;
    int ey = (sel_y1 > sel_y2) ? sel_y1 : sel_y2;
    
    if (sx < 0) sx = 0; if (sy < 0) sy = 0;
    if (ex > 160) ex = 160; if (ey > 120) ey = 120;

    int sel_w = ex - sx;
    int sel_h = ey - sy;

    int center_x = sx + (sel_w / 2);
    int center_y = sy + (sel_h / 2);
    int zoom_center_x = center_x * target_level;
    int zoom_center_y = center_y * target_level;

    int read_start_x = zoom_center_x - (sel_w / 2);
    int read_start_y = zoom_center_y - (sel_h / 2);

    // 3. Renderização na tela (Overlay)
    for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 160; x++) {
            
            unsigned char pixel_val;
            int addr = y * 160 + x;

            if (x >= sx && x < ex && y >= sy && y < ey) {
                int offset_x = x - sx;
                int offset_y = y - sy;
                int zx = read_start_x + offset_x;
                int zy = read_start_y + offset_y;
                
                if (zx < 0) zx = 0; if (zy < 0) zy = 0;
                if (zx >= temp_w) zx = temp_w - 1;
                if (zy >= temp_h) zy = temp_h - 1;

                int zoom_addr = zy * temp_w + zx;
                pixel_val = (unsigned char)fpga_read_pixel(zoom_addr);
            } else {
                pixel_val = img_clean_backup[addr];
            }
            fpga_write_pixel(addr, pixel_val);
        }
    }

    current_zoom_level = target_level;

    // Acende a tela novamente (mostra a imagem pronta)
    fpga_set_blank_pio(0);
}

// ============================================================================
// SELETOR DE MOUSE
// ============================================================================
void run_mouse_selector() {
    int fd;
    struct input_event ev;
    double cx = 80.0, cy = 60.0;
    int dragging = 0;

    printf("\n");
    print_separator();
    printf(C_BOLD "   MODO DE SELEÇÃO" C_RESET "\n");
    printf("   Use o botão esquerdo para arrastar e definir a área.\n");
    print_separator();

    fd = open(MOUSE_DEV, O_RDONLY);
    if (fd == -1) { printf(C_RED "   [ERRO] Mouse não encontrado em %s\n" C_RESET, MOUSE_DEV); return; }
    
    while(read(fd, &ev, sizeof(ev)) > 0 && (ev.type != 0)); 
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    while (1) {
        if (read(fd, &ev, sizeof(ev)) > 0) {
            if (ev.type == EV_REL) {
                if (ev.code == REL_X) cx += ev.value;
                if (ev.code == REL_Y) cy += ev.value;
                cx = fmax(0, fmin(159, cx));
                cy = fmax(0, fmin(119, cy));
                
                printf("\r   " C_CYAN "[MOUSE]" C_RESET " ");
                if (!dragging) {
                    printf("Posição: (%3d, %3d)                      ", (int)cx, (int)cy);
                } else {
                    printf(C_YELLOW "Origem: (%3d, %3d)" C_RESET " >> " C_BOLD "Atual: (%3d, %3d)" C_RESET, 
                           sel_x1, sel_y1, (int)cx, (int)cy);
                }
                fflush(stdout);
            }
            
            if (ev.type == EV_KEY && ev.code == BTN_LEFT) {
                if (ev.value == 1) { 
                    sel_x1 = (int)cx; sel_y1 = (int)cy; dragging = 1;
                } else if (ev.value == 0 && dragging) { 
                    sel_x2 = (int)cx; sel_y2 = (int)cy;
                    printf("\n   " C_GREEN "[✓] Área Capturada!" C_RESET "\n");
                    break;
                }
            }
        }
    }
    close(fd);
    usleep(50000);
}

void handle_zoom_menu() {
    int algo_in;
    char key;

    download_fpga_to_buffer(img_clean_backup, 160, 120);
    current_zoom_level = 1; 

    print_separator();
    printf("   Configuração de Algoritmos:\n");
    
    // PERGUNTA APENAS ZOOM IN
    printf("   [1] Zoom IN (1:Replication, 2:NN): ");
    algo_in = get_validated_input(1, 2);

    if (algo_in == 2) fpga_conf_nearest_neighbor();
    else fpga_conf_replication();
    
    // Define Decimation como padrão para Zoom Out sem perguntar (segurança)
    fpga_conf_decimation();

    run_mouse_selector();

    printf("\n" BG_BLUE C_WHITE C_BOLD "   MODO INTERATIVO " C_RESET "\n");
    printf("   [+] Zoom In  | [-] Zoom Out\n");
    printf("   [Setas] Mover Janela | [q] Sair\n");
    enable_raw_mode();

    // Executa uma vez para desenhar o estado inicial
    execute_zoom_logic(current_zoom_level);

    while(1) {
        printf("\r   " C_BLUE "STATUS |" C_RESET " Zoom: " C_BOLD "%dx" C_RESET " | Pos: (%d,%d) > ", current_zoom_level, sel_x1, sel_y1);
        fflush(stdout);
        
        if (read(STDIN_FILENO, &key, 1) > 0) {
            
            if (key == '\033') { 
                char seq[2];
                if (read(STDIN_FILENO, &seq[0], 1) == 0) continue;
                if (read(STDIN_FILENO, &seq[1], 1) == 0) continue;

                if (seq[0] == '[') {
                    int moved = 0;
                    switch (seq[1]) {
                        case 'A': move_selection_window(0, -MOVE_STEP); moved = 1; break; // Cima
                        case 'B': move_selection_window(0, MOVE_STEP); moved = 1; break;  // Baixo
                        case 'C': move_selection_window(MOVE_STEP, 0); moved = 1; break;  // Direita
                        case 'D': move_selection_window(-MOVE_STEP, 0); moved = 1; break; // Esquerda
                    }
                    if (moved) {
                        execute_zoom_logic(current_zoom_level);
                    }
                }
            }
            else if (key == '+') {
                if (current_zoom_level == 1) execute_zoom_logic(2);
                else if (current_zoom_level == 2) execute_zoom_logic(4);
            } 
            else if (key == '-') {
                if (current_zoom_level == 4) execute_zoom_logic(2);
                else if (current_zoom_level == 2) execute_zoom_logic(1);
            }
            else if (key == 'q' || key == 'Q') {
                break;
            }
        }
    }
    disable_raw_mode();
}

int main() {
    print_header();

    if (fpga_init() < 0) {
        printf(C_RED "   [FATAL] Falha ao inicializar FPGA Driver.\n" C_RESET);
        return -1;
    }
    
    int running = 1;
    int choice;
    char filename[100];

    while (running) {
        printf("\n");
        printf("   " C_BOLD "MENU PRINCIPAL" C_RESET "\n");
        printf("   " C_CYAN "[1]" C_RESET " Iniciar Zoom (Mouse + Controle)\n");
        printf("   " C_CYAN "[2]" C_RESET " Carregar Imagem (.pgm)\n");
        printf("   " C_CYAN "[3]" C_RESET " Salvar Imagem da Tela\n");
        printf("   " C_CYAN "[4]" C_RESET " Sair\n");
        print_separator();
        printf("   Escolha > ");
        
        // Uso da nova função de validação (1 a 4)
        choice = get_validated_input(1, 4);

        switch (choice) {
            case 1:
                handle_zoom_menu();
                print_header();
                break;

            case 2:
                // clear_input_buffer já foi chamado pela validação
                printf("   Nome do arquivo (Padrão: 'image.pgm'): ");
                if (fgets(filename, sizeof(filename), stdin)) {
                    filename[strcspn(filename, "\n")] = 0;
                    if (strlen(filename) == 0) load_file_to_backup("image.pgm");
                    else load_file_to_backup(filename);
                    
                    upload_buffer_to_fpga(img_clean_backup, 160, 120);
                }
                break;

            case 3:
                {
                    unsigned char *temp_dl = malloc(MAX_BUFFER);
                    if (temp_dl) {
                        download_fpga_to_buffer(temp_dl, 160, 120);
                        save_buffer_to_file(temp_dl, 160, 120, "output.pgm");
                        free(temp_dl);
                        printf(C_GREEN "   [✓] Arquivo salvo como 'output.pgm'\n" C_RESET);
                    }
                }
                break;

            case 4:
                running = 0;
                printf(C_MAGENTA "   Encerrando sistema...\n" C_RESET);
                break;
        }
    }

    fpga_close();
    return 0;
}
