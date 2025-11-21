@ =============================================================================
@
@   Arquivo:      lib_api.s (Revisado e Comentado)
@   Descrição:    Este programa controla um hardware customizado (FPGA) via
@                 registradores PIO (Parallel I/O) mapeados em memória.
@                 Ele utiliza exclusivamente chamadas de sistema (syscalls)
@                 Linux para máxima eficiência e independência da libc.
@
@   Funcionalidades Principais:
@   - Exibe um menu de controle para o usuário.
@   - Envia comandos para o FPGA, como zoom e seleção de algoritmos.
@   - Faz o upload de uma imagem PGM (formato P5, binário) para o hardware.
@   - Utiliza a syscall 'lseek' para pular eficientemente o cabeçalho
@     do arquivo de imagem.
@
@   Correção Crucial:
@   O programa diferencia "Ações" (eventos únicos, como zoom) de
@   "Configurações" (modos persistentes, como o algoritmo de interpolação).
@   Ações são seguidas por um comando NOP (No Operation) para evitar que
@   sejam reexecutadas continuamente pelo FPGA, prevenindo uma condição de
@   corrida. Configurações não recebem o NOP para que permaneçam ativas.
@
@ =============================================================================

.arch armv7-a
.fpu vfpv3-d16

.data
@ --- Constantes de Endereçamento de Hardware ---
.equ LW_BRIDGE_BASE,        0xFF200000 @ Endereço base da ponte HPS-FPGA (Lightweight)
.equ LW_BRIDGE_SPAN,        0x00200000 @ Tamanho da janela de memória da ponte
.equ PIO_INSTRUCTION_BASE,  0x00       @ Offset do registrador PIO de instrução

@ --- Constantes de Chamadas de Sistema (Syscall - ARM EABI) ---
.equ SYS_OPEN,              5          @ syscall para abrir um arquivo
.equ SYS_CLOSE,             6          @ syscall para fechar um arquivo
.equ SYS_WRITE,             4          @ syscall para escrever em um arquivo/descritor
.equ SYS_READ,              3          @ syscall para ler de um arquivo/descritor
.equ SYS_MMAP2,             192        @ syscall para mapear memória (endereços > 4GB)
.equ SYS_MUNMAP,            91         @ syscall para desmapear memória
.equ SYS_LSEEK,             19         @ syscall para mover o ponteiro de um arquivo
.equ SYS_NANOSLEEP,         162        @ syscall para pausar a execução com precisão
.equ SYS_EXIT,              1          @ syscall para terminar o programa

@ --- Constantes das Instruções para o FPGA (Opcode nos 3 bits mais significativos) ---
.equ INST_NOP,              (0b000 << 29) @ Nenhuma operação
.equ INST_ZOOM_IN,          (0b001 << 29) @ Ação: aplicar zoom in
.equ INST_ZOOM_OUT,         (0b010 << 29) @ Ação: aplicar zoom out
.equ INST_REPLICATION,      (0b011 << 29) @ Configuração: usar algoritmo de replicação
.equ INST_DECIMATION,       (0b100 << 29) @ Configuração: usar algoritmo de dizimação
.equ INST_NEAREST_NEIGHBOR, (0b101 << 29) @ Configuração: usar vizinho mais próximo
.equ INST_BLOCK_AVERAGE,    (0b110 << 29) @ Configuração: usar média de bloco
.equ INST_UPLOAD_IMAGE,     (0b111 << 29) @ Ação: upload de um pixel de imagem

@ --- Flags e Parâmetros de Operação ---
.equ OPEN_FLAGS,            (0x1000 | 2) @ Flags para open(): O_SYNC | O_RDWR
.equ OPEN_RDONLY,           0            @ Flag para open(): O_RDONLY
.equ PROT_FLAGS,            (1 | 2)      @ Flags para mmap(): PROT_READ | PROT_WRITE
.equ MAP_SHARED,            1            @ Flag para mmap(): MAP_SHARED
.equ IMAGE_WIDTH,           160          @ Largura da imagem em pixels
.equ IMAGE_HEIGHT,          120          @ Altura da imagem em pixels
.equ HEADER_OFFSET,         15           @ Tamanho fixo do cabeçalho PGM a ser pulado
.equ SEEK_SET,              0            @ Flag para lseek(): posicionar a partir do início

@ --- Strings e Estruturas de Dados ---
path_dev_mem:   .asciz "/dev/mem"
path_image:     .asciz "image.pgm"

menu_text:      .asciz "\n--- MENU DE CONTROLE (Syscall version) ---\n"
                .asciz " 1. Zoom In\n"
                .asciz " 2. Zoom Out\n"
                .asciz " 3. Zoom In - Replication\n"
                .asciz " 4. Zoom In - Nearest Neighbor\n"
                .asciz " 5. Zoom Out - Decimation\n"
                .asciz " 6. Zoom Out - Block Average\n"
                .asciz " 7. Carregar 'image.pgm' (P5 Fast)\n"
                .asciz " 0. Sair\n"
                .asciz "Escolha uma opcao: "
menu_len = . - menu_text

upload_start_msg:   .asciz "Iniciando upload de 'image.pgm'...\n"
upload_start_len = . - upload_start_msg
upload_ok_msg:      .asciz "Upload concluido com sucesso.\n"
upload_ok_len = . - upload_ok_msg
upload_err_msg:     .asciz "ERRO durante o upload.\n"
upload_err_len = . - upload_err_msg

@ Estrutura 'timespec' para a syscall nanosleep (1 milissegundo)
time_1ms:
    .word 0         @ segundos
    .word 1000000   @ nanosegundos (10^6 ns = 1 ms)
@ Estrutura 'timespec' para a syscall nanosleep (50 microssegundos)
time_50us:
    .word 0         @ segundos
    .word 50000     @ nanosegundos (5 * 10^4 ns = 50 us)

.text
.global _start
_start:
    @ --- Preservar Registradores ---
    @ Salva na pilha os registradores que serão modificados, conforme a convenção ARM
    push    {r4-r11, lr}

    @ --- Mapeamento de Memória para Acesso ao Hardware ---
    @ O objetivo é obter um ponteiro virtual (no espaço de endereçamento do processo)
    @ que aponte para o endereço físico do hardware (PIO no FPGA).
    @
    @ Registradores utilizados nesta seção:
    @ R4: File descriptor para /dev/mem
    @ R5: Endereço virtual base da ponte LW_BRIDGE
    @ R6: Endereço virtual final do registrador PIO

    @ 1. Abrir /dev/mem para ter acesso à memória física
    ldr     r0, =path_dev_mem   @ R0 = Endereço do path "/dev/mem"
    ldr     r1, =OPEN_FLAGS     @ R1 = Flags (O_SYNC | O_RDWR)
    mov     r7, #SYS_OPEN       @ R7 = syscall ID para 'open'
    svc     #0                  @ Executa a chamada de sistema
    mov     r4, r0              @ Salva o file descriptor em R4

    @ 2. Mapear a região de memória da ponte HPS-FPGA no espaço de endereçamento do programa
    mov     r0, #0                      @ R0 = offset (não usado com mmap2)
    ldr     r1, =LW_BRIDGE_SPAN         @ R1 = tamanho da região a ser mapeada
    mov     r2, #PROT_FLAGS             @ R2 = proteção (leitura e escrita)
    mov     r3, #MAP_SHARED             @ R3 = flags (alterações visíveis para outros processos)
    mov     r4, r4                      @ R4 = file descriptor de /dev/mem (já está lá)
    ldr     r5, =LW_BRIDGE_BASE         @ Carrega o endereço físico base
    lsr     r5, r5, #12                 @ mmap2 espera o offset em unidades de 4KB (page size)
    mov     r7, #SYS_MMAP2              @ R7 = syscall ID para 'mmap2'
    svc     #0                          @ Executa a chamada de sistema
    mov     r5, r0                      @ Salva o endereço virtual base retornado em R5

    @ 3. Calcular o endereço final do PIO
    add     r6, r5, #PIO_INSTRUCTION_BASE @ Endereço final = Base virtual + offset do PIO

    @ Garante que o hardware comece em um estado conhecido e limpo
    mov     r0, #INST_NOP       @ Carrega a instrução NOP
    str     r0, [r6]            @ Escreve NOP no PIO

@ =============================================================================
@   LOOP PRINCIPAL
@ =============================================================================
main_loop:
    @ Exibe o menu para o usuário
    mov     r0, #1              @ R0 = stdout
    ldr     r1, =menu_text      @ R1 = Endereço do texto do menu
    ldr     r2, =menu_len       @ R2 = Tamanho do texto
    mov     r7, #SYS_WRITE      @ R7 = syscall ID para 'write'
    svc     #0

    @ Lê a entrada do usuário (um caractere)
    sub     sp, sp, #4          @ Aloca espaço na pilha para o caractere
    mov     r0, #0              @ R0 = stdin
    mov     r1, sp              @ R1 = Endereço do buffer (na pilha)
    mov     r2, #4              @ R2 = Tamanho do buffer
    mov     r7, #SYS_READ       @ R7 = syscall ID para 'read'
    svc     #0
    ldrb    r0, [sp]            @ Carrega o byte lido (caractere ASCII)
    add     sp, sp, #4          @ Libera o espaço na pilha
    sub     r0, r0, #'0'        @ Converte o caractere ASCII ('0'-'9') para inteiro (0-9)

    @ --- Lógica de Despacho (Branch) ---
    @ Compara a entrada do usuário e salta para a rotina correspondente.
    cmp     r0, #0
    beq     cleanup_and_exit    @ Se for 0, sai do programa

    @ Opções 1 e 2 são "AÇÕES": executam uma vez e param.
    cmp     r0, #1
    ldreq   r1, =INST_ZOOM_IN   @ Carrega a instrução em R1 se for igual
    beq     call_send_action

    cmp     r0, #2
    ldreq   r1, =INST_ZOOM_OUT
    beq     call_send_action

    @ Opções 3, 4, 5 e 6 são "CONFIGURAÇÕES": definem um modo que permanece ativo.
    cmp     r0, #3
    ldreq   r1, =INST_REPLICATION
    beq     call_set_config

    cmp     r0, #4
    ldreq   r1, =INST_NEAREST_NEIGHBOR
    beq     call_set_config

    cmp     r0, #5
    ldreq   r1, =INST_DECIMATION
    beq     call_set_config

    cmp     r0, #6
    ldreq   r1, =INST_BLOCK_AVERAGE
    beq     call_set_config

    @ Opção 7 é o upload da imagem
    cmp     r0, #7
    beq     call_upload_image

    @ Se a opção for inválida, simplesmente volta ao início do loop
    b       main_loop

@ --- Rotinas de Chamada ---
@ Encapsulam a lógica de chamada e o retorno ao loop principal
call_send_action:
    bl      send_action_instruction @ Chama a sub-rotina para "ações"
    b       main_loop

call_set_config:
    bl      set_config_instruction  @ Chama a sub-rotina para "configurações"
    b       main_loop

call_upload_image:
    bl      upload_image_syscall    @ Chama a sub-rotina de upload
    b       main_loop

@ =============================================================================
@   FUNÇÕES DE COMUNICAÇÃO COM O PIO
@ =============================================================================

@ -----------------------------------------------------------------------------
@   send_action_instruction
@   Envia uma instrução de AÇÃO (e.g., Zoom In/Out).
@   Após enviar a instrução, espera um curto período e envia um NOP.
@   Entrada: R1 = Instrução de 32 bits a ser enviada
@ -----------------------------------------------------------------------------
send_action_instruction:
    push    {lr}                @ Salva o endereço de retorno

    str     r1, [r6]            @ Envia a instrução (R1) para o PIO (endereço em R6)

    @ Pausa para dar tempo ao FPGA para processar a ação
    ldr     r0, =time_1ms       @ R0 = Endereço da estrutura 'timespec' de 1ms
    mov     r1, #0              @ R1 = Endereço para 'remainder' (não usado)
    mov     r7, #SYS_NANOSLEEP
    svc     #0

    @ Limpa o registrador de instrução para evitar re-execução
    mov     r0, #INST_NOP
    str     r0, [r6]

    pop     {pc}                @ Retorna da função

@ -----------------------------------------------------------------------------
@   set_config_instruction
@   Envia uma instrução de CONFIGURAÇÃO (e.g., selecionar algoritmo).
@   Apenas envia a instrução e retorna.
@   Entrada: R1 = Instrução de 32 bits a ser enviada
@ -----------------------------------------------------------------------------
set_config_instruction:
    push    {lr}                @ Salva o endereço de retorno
    str     r1, [r6]            @ Apenas envia a instrução de configuração
    pop     {pc}                @ Retorna imediatamente

@ =============================================================================
@   FINALIZAÇÃO
@ =============================================================================
cleanup_and_exit:
    @ Desmapeia a memória da ponte
    mov     r0, r5              @ R0 = Endereço virtual base
    ldr     r1, =LW_BRIDGE_SPAN @ R1 = Tamanho da região
    mov     r7, #SYS_MUNMAP
    svc     #0

    @ Fecha o descritor de arquivo /dev/mem
    mov     r0, r4              @ R0 = File descriptor
    mov     r7, #SYS_CLOSE
    svc     #0

    @ Termina o programa
    mov     r0, #0              @ R0 = Código de saída (0 = sucesso)
    mov     r7, #SYS_EXIT
    svc     #0

@ =============================================================================
@   FUNÇÃO: upload_image_syscall
@   Realiza o upload de uma imagem PGM (formato P5) para o hardware.
@   - Abre o arquivo 'image.pgm'.
@   - Usa lseek para pular o cabeçalho de 15 bytes.
@   - Lê o arquivo pixel por pixel.
@   - Para cada pixel, monta uma instrução de 32 bits e a envia ao PIO.
@   Formato da Instrução:
@   | 31-29: Opcode (INST_UPLOAD_IMAGE) | 28-14: Endereço do Pixel | 13-8: Não usado | 7-0: Valor do Pixel |
@ =============================================================================
upload_image_syscall:
    push    {r4-r11, lr}        @ Preserva os registradores
    sub     sp, sp, #8          @ Aloca espaço na pilha (fd e byte do pixel)

    @ Mensagem inicial
    mov     r0, #1
    ldr     r1, =upload_start_msg
    ldr     r2, =upload_start_len
    mov     r7, #SYS_WRITE
    svc     #0

    @ 1. Abrir o arquivo de imagem
    ldr     r0, =path_image
    mov     r1, #OPEN_RDONLY    @ Abre em modo somente leitura
    mov     r7, #SYS_OPEN
    svc     #0
    cmp     r0, #0              @ Verifica se houve erro (retorno < 0)
    blt     upload_error
    str     r0, [sp, #0]        @ Salva o file descriptor na pilha

    @ 2. Pular o cabeçalho PGM usando lseek
    ldr     r0, [sp, #0]        @ R0 = File descriptor
    mov     r1, #HEADER_OFFSET  @ R1 = Offset para pular (15 bytes)
    mov     r2, #SEEK_SET       @ R2 = Posicionar a partir do início do arquivo
    mov     r7, #SYS_LSEEK
    svc     #0
    cmp     r0, #0              @ Verifica se houve erro
    blt     upload_error

    @ 3. Loop de upload de pixels
    mov     r10, #0             @ R10 = Contador de pixels (endereço do pixel)
upload_lseek_loop:
    cmp     r10, #(IMAGE_WIDTH * IMAGE_HEIGHT) @ Verifica se todos os pixels foram enviados
    bge     upload_success

    @ Lê um único byte (pixel) do arquivo
    ldr     r0, [sp, #0]        @ R0 = File descriptor
    add     r1, sp, #4          @ R1 = Buffer de 1 byte na pilha
    mov     r2, #1              @ R2 = Quantidade de bytes a ler
    mov     r7, #SYS_READ
    svc     #0
    cmp     r0, #1              @ Se read não retornou 1, é um erro ou fim de arquivo
    bne     upload_error
    
    @ Carrega o byte lido para o registrador R9
    add     r1, sp, #4
    ldrb    r9, [r1]            @ R9 = Valor do pixel (0-255)

    @ Monta a instrução de 32 bits
    ldr     r0, =INST_UPLOAD_IMAGE          @ Começa com o opcode de upload
    orr     r0, r0, r9                      @ Combina (OR) com o valor do pixel (bits 0-7)
    orr     r0, r0, r10, lsl #14            @ Combina com o endereço do pixel (deslocado para bits 14-28)
    
    @ Envia a instrução para o hardware
    str     r0, [r6]

    @ Pausa curta entre pixels para o hardware acompanhar
    ldr     r0, =time_50us
    mov     r1, #0
    mov     r7, #SYS_NANOSLEEP
    svc     #0

    add     r10, r10, #1        @ Incrementa o contador de pixels
    b       upload_lseek_loop

upload_success:
    mov     r0, #INST_NOP       @ Envia NOP ao final do upload
    str     r0, [r6]
    mov     r0, #1
    ldr     r1, =upload_ok_msg
    ldr     r2, =upload_ok_len
    mov     r7, #SYS_WRITE
    svc     #0
    b       upload_cleanup

upload_error:
    mov     r0, #1              @ Escreve mensagem de erro no stdout
    ldr     r1, =upload_err_msg
    ldr     r2, =upload_err_len
    mov     r7, #SYS_WRITE
    svc     #0

upload_cleanup:
    ldr     r0, [sp, #0]        @ Carrega o file descriptor
    mov     r7, #SYS_CLOSE      @ Fecha o arquivo de imagem
    svc     #0
    add     sp, sp, #8          @ Libera espaço da pilha
    pop     {r4-r11, pc}        @ Restaura registradores e retorna