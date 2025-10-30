// Arquivo: main.v (COMPLETO E ATUALIZADO)

module main (
    // Entradas da FPGA
    input wire clock_50,
    input wire reset_signal,
        
    input wire [31:0] instruction,
    input wire        begin_flag,

    output wire       done_flag, // Conexão para o HPS

    // Saídas para o VGA
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
    // 1. FIOS DE CONTROLE E DADOS
    // =========================================================
    
    wire clock_25;
    
    wire       program_state;
    wire [3:0] operation; // LARGURA AUMENTADA
    wire [1:0] display_mode;
    wire       processing_done;

    // Fios para os dados de pixel e flag de reset
    wire [7:0] pixel_data_1;
    wire [7:0] pixel_data_2;
    wire [7:0] pixel_data_3;
    wire       upload_reset_wire;

    wire [18:0] proc_ram_address;
    wire [7:0]  proc_ram_data_in;
    wire        proc_ram_wren;
    wire [16:0] proc_rom_address;
    
    wire [18:0] final_ram_address;
    wire        final_ram_wren;
    
    wire [7:0]  proc_rom_q_out;
    wire [7:0]  ram_q_out;

    wire [18:0] video_ram_address;
    wire [31:0] instruct_out;

    // =========================================================
    // 2. MÓDULOS BASE (Clock e Reset)
    // =========================================================

    clock_divider clock_divider_inst ( .clock_in(clock_50), .clock_out(clock_25) );
    instruct_memory instruct_inst( .instruction(instruction), .signal(begin_flag), .instruct_out(instruct_out) );

    // =========================================================
    // 3. UNIDADES DE CONTROLE E PROCESSAMENTO
    // =========================================================

    control_unit control_unit_inst (
        .clock(clock_25), .reset(reset_signal), .processing_done(processing_done),
        .instruct(instruct_out), .begin_f(begin_flag), .done_instruction(done_flag),
        .program_state(program_state), .operation(operation), .display_mode(display_mode),
        .pixel_out_1(pixel_data_1), .pixel_out_2(pixel_data_2), .pixel_out_3(pixel_data_3),
        .upload_reset_out(upload_reset_wire)
    );
    
    processing_unit processing_unit_inst (
        .clock(clock_25), .reset(reset_signal),
        .program_state(program_state), .operation(operation),
        .pixel_in_1(pixel_data_1), .pixel_in_2(pixel_data_2), .pixel_in_3(pixel_data_3),
        .upload_reset_flag(upload_reset_wire),
        .rom_q_out_in(proc_rom_q_out), .rom_addr_out(proc_rom_address),
        .ram_addr_out(proc_ram_address), .ram_data_out(proc_ram_data_in),
        .ram_wren_out(proc_ram_wren), .processing_done(processing_done)
    );
    
    // =========================================================
    // 4. MÓDULOS CORE (Memória e Vídeo)
    // =========================================================

    assign final_ram_address = (program_state == 1'b1) ? proc_ram_address : video_ram_address;
    assign final_ram_wren    = (program_state == 1'b1) ? proc_ram_wren : 1'b0;

    memory_module mem_inst (
        .clock(clock_25), .reset(reset_signal),
        .ram_address(final_ram_address), .ram_data_in(proc_ram_data_in), .wren_in(final_ram_wren),
        .q_out_ram(ram_q_out), .rom_address_ext(proc_rom_address), .q_out_rom(proc_rom_q_out),
        .done()
    );

    video_controller video_inst (
        .clk(clock_25), .reset(reset_signal), .display_mode(display_mode),
        .ram_data_in(ram_q_out), .processing_active(program_state), 
        .ram_addr_out(video_ram_address), .hsync(hsync), .vsync(vsync), .red(red), .green(green), 
        .blue(blue), .sync(sync), .clk_out(clk_out), .blank(blank)
    );
    defparam video_inst.BACKGROUND_COLOR = SCREEN_COLOR;

endmodule