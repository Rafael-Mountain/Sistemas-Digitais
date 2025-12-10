@ =============================================================================
@   Arquivo:      lib_fpga.s
@   Descrição:    Driver FPGA Robusto (Com Timeouts para evitar travamento)
@ =============================================================================

    .arch armv7-a
    .text
    .align 4

    .extern open
    .extern close
    .extern mmap
    .extern munmap
    .extern usleep

    .global fpga_init
    .global fpga_close
    .global fpga_send_action
    .global fpga_set_config
    .global fpga_read_pixel
    .global fpga_write_pixel
    .global fpga_set_blank_pio

    @ --- CONSTANTES DE ENDEREÇO (CONFIRA NO QSYS) ---
    .equ LW_BRIDGE_BASE,    0xFF200000
    .equ LW_BRIDGE_SPAN,    0x00200000
    
    .equ OFFSET_PIO_INSTR,  0x00
    .equ OFFSET_PIO_DATA,   0x10
    .equ OFFSET_PIO_DONE,   0x20
    .equ OFFSET_PIO_BLANK,  0x30  @ <--- Endereço do PIO de Blank

    .equ O_RDWR_SYNC,       0x1002
    .equ PROT_READ_WRITE,   3
    .equ MAP_SHARED,        1
    
    .equ INST_NOP,          (0b0000 << 28)
    .equ INST_UPLOAD_IMAGE, (0b0111 << 28)
    .equ INST_READ_PIXEL,   (0b1000 << 28)
    
    @ Constante para Timeout (aprox. ciclos de CPU para desistir)
    .equ TIMEOUT_LIMIT,     0x100000 

    .data
    .align 4

base_ptr:       .word 0
pio_instr_ptr:  .word 0
pio_data_ptr:   .word 0
pio_done_ptr:   .word 0
pio_blank_ptr:  .word 0
fd_mem:         .word 0
path_dev_mem:   .asciz "/dev/mem"

    .text

@ --- fpga_init ---
    .type fpga_init, %function
fpga_init:
    push    {r4-r6, lr}
    ldr     r0, =path_dev_mem
    ldr     r1, =O_RDWR_SYNC
    bl      open
    cmp     r0, #0
    blt     init_error

    ldr     r1, =fd_mem
    str     r0, [r1]
    mov     r4, r0

    push    {r4, r5}
    ldr     r5, =LW_BRIDGE_BASE
    str     r5, [sp, #4]
    str     r4, [sp, #0]
    mov     r0, #0
    ldr     r1, =LW_BRIDGE_SPAN
    mov     r2, #PROT_READ_WRITE
    mov     r3, #MAP_SHARED
    bl      mmap
    add     sp, sp, #8

    cmn     r0, #1
    beq     init_error_close

    ldr     r1, =base_ptr
    str     r0, [r1]

    @ Configura ponteiros
    add     r2, r0, #OFFSET_PIO_INSTR
    ldr     r1, =pio_instr_ptr
    str     r2, [r1]

    ldr     r0, =base_ptr
    ldr     r0, [r0]
    add     r2, r0, #OFFSET_PIO_DATA
    ldr     r1, =pio_data_ptr
    str     r2, [r1]

    ldr     r0, =base_ptr
    ldr     r0, [r0]
    add     r2, r0, #OFFSET_PIO_DONE
    ldr     r1, =pio_done_ptr
    str     r2, [r1]
    
    ldr     r0, =base_ptr
    ldr     r0, [r0]
    add     r2, r0, #OFFSET_PIO_BLANK
    ldr     r1, =pio_blank_ptr
    str     r2, [r1]

    @ Reset inicial
    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    mov     r2, #INST_NOP
    str     r2, [r3]
    
    @ Reset Blank (0 = Tela Ligada)
    ldr     r3, =pio_blank_ptr
    ldr     r3, [r3]
    mov     r2, #0
    str     r2, [r3]

    mov     r0, #0
    pop     {r4-r6, pc}

init_error_close:
    ldr     r0, =fd_mem
    ldr     r0, [r0]
    bl      close
init_error:
    mvn     r0, #0
    pop     {r4-r6, pc}
    .size fpga_init, .-fpga_init

@ --- fpga_close ---
    .type fpga_close, %function
fpga_close:
    push    {r4, lr}
    ldr     r4, =base_ptr
    ldr     r0, [r4]
    cmp     r0, #0
    beq     do_close_fd
    ldr     r1, =LW_BRIDGE_SPAN
    bl      munmap
    mov     r0, #0
    str     r0, [r4]
do_close_fd:
    ldr     r4, =fd_mem
    ldr     r0, [r4]
    cmp     r0, #0
    beq     close_exit
    bl      close
close_exit:
    pop     {r4, pc}
    .size fpga_close, .-fpga_close

@ --- fpga_send_action ---
    .type fpga_send_action, %function
fpga_send_action:
    push    {r4, lr}
    mov     r4, r0
    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    cmp     r3, #0
    beq     action_exit

    str     r4, [r3]
    mov     r0, #1000
    bl      usleep

    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    mov     r2, #INST_NOP
    str     r2, [r3]
action_exit:
    pop     {r4, pc}
    .size fpga_send_action, .-fpga_send_action

@ --- fpga_set_config ---
    .type fpga_set_config, %function
fpga_set_config:
    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    cmp     r3, #0
    bxeq    lr
    str     r0, [r3]
    bx      lr
    .size fpga_set_config, .-fpga_set_config

@ --- fpga_set_blank_pio ---
    .type fpga_set_blank_pio, %function
fpga_set_blank_pio:
    ldr     r3, =pio_blank_ptr
    ldr     r3, [r3]
    cmp     r3, #0
    bxeq    lr
    
    and     r0, r0, #1
    str     r0, [r3]
    bx      lr
    .size fpga_set_blank_pio, .-fpga_set_blank_pio

@ --- fpga_write_pixel (BLINDADO) ---
    .type fpga_write_pixel, %function
fpga_write_pixel:
    push    {r4, lr}

    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    
    ldr     r2, =INST_UPLOAD_IMAGE
    and     r1, r1, #0xFF
    orr     r2, r2, r1
    
    ldr     r4, =0x7FFF
    and     r0, r0, r4
    orr     r2, r2, r0, lsl #8

    @ 1. Escreve Instrução
    str     r2, [r3]

    @ 2. Delay AUMENTADO (De 300 para 2000 ciclos)
    @ Garante que a FPGA capture mesmo com latência
    mov     r4, #2000
write_delay:
    subs    r4, r4, #1
    bne     write_delay

    @ 3. Escreve NOP e Delay curto para limpeza
    mov     r2, #INST_NOP
    str     r2, [r3]
    
    mov     r4, #100
nop_delay:
    subs    r4, r4, #1
    bne     nop_delay
    
    pop     {r4, pc}
    .size fpga_write_pixel, .-fpga_write_pixel

@ --- fpga_read_pixel (COM TIMEOUT) ---
    .type fpga_read_pixel, %function
fpga_read_pixel:
    push    {r4, r5, r6, lr}
    
    @ Monta instrução
    ldr     r2, =INST_READ_PIXEL
    ldr     r3, =0x7FFFF
    and     r0, r0, r3
    orr     r0, r0, r2
    
    ldr     r3, =pio_instr_ptr
    ldr     r3, [r3]
    ldr     r4, =pio_done_ptr
    ldr     r4, [r4]
    ldr     r1, =pio_data_ptr
    ldr     r1, [r1]

    @ 1. Escreve Instrução
    str     r0, [r3]

    @ 2. Espera DONE = 1 (COM TIMEOUT)
    ldr     r6, =TIMEOUT_LIMIT
wait_done_high:
    ldr     r5, [r4]
    tst     r5, #1
    bne     read_data_ok     @ Se 1, sucesso, sai do loop
    
    subs    r6, r6, #1       @ Decrementa timeout
    bne     wait_done_high   @ Se não zerou, continua
    
    @ TIMEOUT OCORREU! (FPGA não respondeu)
    @ Vamos forçar NOP e retornar 0 para destravar o sistema
    b       force_exit_nop

read_data_ok:
    @ 3. Lê o Dado
    ldr     r0, [r1]
    and     r0, r0, #0xFF

force_exit_nop:
    @ 4. Escreve NOP
    mov     r5, #INST_NOP
    str     r5, [r3]

    @ 5. Espera DONE = 0 (COM TIMEOUT)
    ldr     r6, =TIMEOUT_LIMIT
wait_done_low:
    ldr     r5, [r4]
    tst     r5, #1
    beq     exit_read        @ Se 0, sucesso, sai
    
    subs    r6, r6, #1
    bne     wait_done_low
    
    @ Se der timeout aqui, apenas saímos, pois o NOP já foi enviado

exit_read:
    pop     {r4, r5, r6, pc}
    .size fpga_read_pixel, .-fpga_read_pixel