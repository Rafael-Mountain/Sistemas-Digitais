// main.v - Top-Level Module (Modularizado e Corrigido)
module main (
    // Entradas da FPGA
    input wire clock_50,          // Clock de 50MHz da placa
    input wire reset_button,      // Botão de reset (ativo-baixo)
    input wire zoom_out_button,
    input wire zoom_in_button,
    input wire algorithm_select,  // Chave: 0 para Set 1, 1 para Set 2

    // Saidas para o VGA
    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk_out,
    output wire blank
);

    // --- PARÂMETROS GLOBAIS ---
    localparam [7:0] SCREEN_COLOR = 8'h24;

    // =========================================================
    // 1. FIOS DE CONTROLE E DADOS (Declaração obrigatória antes do uso)
    // =========================================================
    
    // Clock e Reset
    wire clock_25;     // Clock de 25MHz
    wire reset_sync;   // Reset sincronizado (ativo-alto)
    
    // Sinais de Controle da FSM (Vindos da control_unit)
    wire program_state;  // 1'b0 (WAITING/IDLE) ou 1'b1 (PROCESSING)
    wire [1:0] operation;  // ORIGINAL, ZOOM_OUT, ZOOM_IN, NONE
    wire [1:0] display_mode; // ORIGINAL, ZOOM_OUT, ZOOM_IN
    wire processing_done; // Sinal de conclusão (vindo da processing_unit)

    // Sinais de Memória do Processador (Vindos da processing_unit)
    wire [18:0] proc_ram_address;
    wire [7:0]  proc_ram_data_in;
    wire        proc_ram_wren; // Corrigido para 1 bit, se ram_wren for 1 bit
    wire [16:0] proc_rom_address;
    
    // Sinais de Memória Final (Árbitro)
    wire [18:0] final_ram_address;
    wire        final_ram_wren;
    
    // Sinais de Dados (Lidos/Escritos na memory_module)
    wire [7:0]  proc_rom_q_out;  // Dado lido da ROM (para processing_unit)
    wire [7:0]  ram_q_out;     // Dado lido da RAM (para video_controller)

    // Sinais de Memória do Vídeo (Vindos da video_controller)
    wire [18:0] video_ram_address;

    // =========================================================
    // 2. MÓDULOS BASE (Clock e Reset)
    // =========================================================

    // Módulo Divisor de Clock (50MHz -> 25MHz)
    clock_divider clock_divider_inst (
        .clock_in(clock_50),
        .clock_out(clock_25)
    );
    
    // Módulo de Sincronização e Reset (garante reset síncrono)
    sync_reset_button sync_reset_button_inst (
        .clock(clock_25),
        .reset_button_in(reset_button), // Botão ativo-baixo
        .reset_sync_out(reset_sync)     // Reset sincronizado ativo-alto
    );

    // =========================================================
    // 3. UNIDADES DE CONTROLE E PROCESSAMENTO
    // =========================================================

    // Unidade de Controle (FSM e Detecção de Botões)
    control_unit control_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .zoom_in_signal(~zoom_in_button), // Converte para ativo-alto
        .zoom_out_signal(~zoom_out_button), // Converte para ativo-alto
        .processing_done(processing_done),

        .program_state(program_state), 
        .operation(operation),       
        .display_mode(display_mode)  
    );
    
    // Unidade de Processamento (Instanciação de Algoritmos e Arbitragem Interna)
    processing_unit processing_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .algorithm_select(algorithm_select),
        
        .program_state(program_state),
        .operation(operation),
        
        .rom_q_out_in(proc_rom_q_out),
        .rom_addr_out(proc_rom_address),
        .ram_addr_out(proc_ram_address),
        .ram_data_out(proc_ram_data_in),
        .ram_wren_out(proc_ram_wren),
        
        .processing_done(processing_done)
        // A porta 'display_mode' foi removida do módulo, pois não era utilizada.
    );
    
    // =========================================================
    // 4. MÓDULOS CORE (Memória e Vídeo)
    // =========================================================

    // MÓDULO DE ARBITRAGEM DE MEMÓRIA FINAL (Processador vs. VGA)
    // O Processador (program_state = 1) tem prioridade de escrita.
    assign final_ram_address = (program_state == 1'b1) ? proc_ram_address : video_ram_address;
    assign final_ram_wren    = (program_state == 1'b1) ? proc_ram_wren : 1'b0;

    // MÓDULO DE MEMÓRIA (RAM e ROM)
    memory_module mem_inst (
        .clock(clock_25), .reset(reset_sync),
        .ram_address(final_ram_address),    // Endereço arbitrado
        .ram_data_in(proc_ram_data_in),     // Dados da Processing Unit
        .wren_in(final_ram_wren),           // wren arbitrado
        .q_out_ram(ram_q_out),              // Dados de saída para o VGA
        .rom_address_ext(proc_rom_address), // Endereço de leitura da ROM
        .q_out_rom(proc_rom_q_out),         // Dados de saída para a Processing Unit
        .done()
    );

    // MÓDULO DE VÍDEO (Controlador VGA)
    video_controller video_inst (
        .clk(clock_25),
        .reset(reset_sync),
        .display_mode(display_mode),
        .ram_data_in(ram_q_out),           
        .processing_active(program_state), 
        .ram_addr_out(video_ram_address),   
        
        // Saídas VGA
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), 
        .blue(blue), .sync(sync), .clk_out(clk_out), .blank(blank)
    );
    defparam video_inst.BACKGROUND_COLOR = SCREEN_COLOR;

endmodule