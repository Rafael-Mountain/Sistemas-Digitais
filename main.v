module main (
    // --- Entradas da FPGA ---
    input wire clock_50,      // Clock de 50MHz da placa
    input wire reset_button,    // Botão de reset (ativo-baixo)
    input wire zoom_in_button,   // Botão de zoom in (ativo-baixo)
    input wire zoom_out_button,   // Botão de zoom out (ativo-baixo)
    input wire algorithm_select,  // Chave para seleção de algoritmo (0=Set 1, 1=Set 2)

    // --- Saídas VGA ---
    output wire hsync, output wire vsync,
    output wire [7:0] red, output wire [7:0] green, output wire [7:0] blue,
    output wire sync, output wire clk_out, output wire blank
);

	 wire pll_clk, pll_locked; 
    pll pll_inst (.refclk(clk), .rst(~reset_button), .outclk_0(pll_clk), .locked(pll_locked));

    // --- PARÂMETROS GLOBAIS ---
    localparam [7:0] SCREEN_COLOR = 8'h24; 

    // --- FIOS DE INFRAESTRUTURA E CONTROLE ---
    wire clock_25;     // Clock de trabalho (25MHz)
    reg reset_sync;    // Reset sincronizado
    wire processing_done; // Feedback: Coprocessador concluiu
    
    // Sinais da Unidade de Controle (FSM)
    wire control_processing_active;
    wire [2:0] control_operation;   
    wire [1:0] control_display_mode;

    // =================================================================
    // --- FIOS INTERNOS DE BARRAMENTO E COPROCESSADORES (ALUs) ---
    // =================================================================
    
    // Barramento Principal (Controlado pelo Árbitro de Memória)
    wire [16:0] proc_rom_address;   
    wire [18:0] proc_ram_address;   
    wire [7:0] proc_ram_data_in;   
    wire proc_ram_wren;            

    wire [18:0] video_ram_address;  
    wire [18:0] final_ram_address;  
    wire final_ram_wren;           
    wire [7:0] ram_q_out;          
    wire [7:0] proc_rom_q_out;     

    // Fios de Interface de CADA Coprocessador (para o Árbitro)
    wire start_copy, start_zi1, start_zo1, start_zi2, start_zo2;
    
    wire [16:0] rom_addr_copy, rom_addr_zi1, rom_addr_zo1, rom_addr_zi2, rom_addr_zo2;
    wire [18:0] ram_addr_copy, ram_addr_zi1, ram_addr_zo1, ram_addr_zi2, ram_addr_zo2;
    wire [7:0] ram_data_copy, ram_data_zi1, ram_data_zo1, ram_data_zi2, ram_data_zo2;
    wire ram_wren_copy, ram_wren_zi1, ram_wren_zo1, ram_wren_zi2, ram_wren_zo2;
    wire done_copy, done_zi1, done_zo1, done_zi2, done_zo2;
    
    // =================================================================
    // --- 1. CLOCKS, RESETS E UNIDADE DE CONTROLE (CU) ---
    // =================================================================

    clock_divider inst_clock_divider (.clock_in(clock_50), .clock_out(clock_25));
    always @(posedge clock_25) begin
        reset_sync <= ~reset_button; 
    end

    // Instância da Unidade de Controle (FSM)
    control_unit control_inst (
        .clock(clock_25),.reset_sync(reset_sync),
        .zoom_in_signal(~zoom_in_button), .zoom_out_signal(~zoom_out_button),
        .processing_done(processing_done), 
        .processing_active(control_processing_active),
        .operation(control_operation), 
        .display_mode(control_display_mode)
    );
    
    // =================================================================
    // --- 2. ÁRBITRO DE PROCESSAMENTO (Gera STARTs e Roteia) ---
    // =================================================================
    
    processing_arbiter proc_arb_inst (
        .operation(control_operation), .processing_active(control_processing_active),
        .algorithm_select(algorithm_select),
        
        // Entradas de Conclusão (Done)
        .done_copy(done_copy), .done_zi1(done_zi1), .done_zo1(done_zo1), .done_zi2(done_zi2), .done_zo2(done_zo2),
        
        // Saídas START (para as instâncias abaixo)
        .start_copy(start_copy), .start_zi1(start_zi1), .start_zo1(start_zo1), .start_zi2(start_zi2), .start_zo2(start_zo2),
        
        // Conexão dos barramentos (Entrada/Saída)
        .rom_addr_copy(rom_addr_copy), .ram_addr_copy(ram_addr_copy), .ram_data_copy(ram_data_copy), .ram_wren_copy(ram_wren_copy),
        .rom_addr_zi1(rom_addr_zi1), .ram_addr_zi1(ram_addr_zi1), .ram_data_zi1(ram_data_zi1), .ram_wren_zi1(ram_wren_zi1),
        .rom_addr_zo1(rom_addr_zo1), .ram_addr_zo1(ram_addr_zo1), .ram_data_zo1(ram_data_zo1), .ram_wren_zo1(ram_wren_zo1),
        .rom_addr_zi2(rom_addr_zi2), .ram_addr_zi2(ram_addr_zi2), .ram_data_zi2(ram_data_zi2), .ram_wren_zi2(ram_wren_zi2),
        .rom_addr_zo2(rom_addr_zo2), .ram_addr_zo2(ram_addr_zo2), .ram_data_zo2(ram_data_zo2), .ram_wren_zo2(ram_wren_zo2),
        
        // Saídas Roteadas
        .proc_rom_address(proc_rom_address), .proc_ram_address(proc_ram_address),
        .proc_ram_data_in(proc_ram_data_in), .proc_ram_wren(proc_ram_wren),
        .processing_done(processing_done) 
    );

    // =================================================================
    // --- 3. INSTÂNCIAS DOS COPROCESSADORES (ALUS) ---
    // =================================================================
    
    // Instância 1: Cópia (OP_ORIGINAL/OP_COPY)
    copy_rom_to_ram copy_inst (
        .clk(clock_25), .reset(reset_sync), .start(start_copy), 
        .rom_addr(rom_addr_copy), .rom_data(proc_rom_q_out), // Dado lido da ROM
        .ram_addr(ram_addr_copy), .ram_data(ram_data_copy), .ram_wren(ram_wren_copy),
        .done(done_copy)
    );
    
    // Instância 2: Zoom In - Set 1 (Replication)
    zoom_in_replication zi_rep_inst (
        .clk(clock_25), .reset(reset_sync), .start(start_zi1),
        .rom_addr(rom_addr_zi1), .rom_data(proc_rom_q_out), 
        .ram_addr(ram_addr_zi1), .ram_data(ram_data_zi1), .ram_wren(ram_wren_zi1), .done(done_zi1)
    );
    
    // Instância 3: Zoom Out - Set 1 (Decimation)
    zoom_out_decimation zo_dec_inst (
        .clk(clock_25), .reset(reset_sync), .start(start_zo1),
        .rom_addr(rom_addr_zo1), .rom_data(proc_rom_q_out), 
        .ram_addr(ram_addr_zo1), .ram_data(ram_data_zo1), .ram_wren(ram_wren_zo1), .done(done_zo1)
    );

    // Instância 4: Zoom In - Set 2 (Nearest Neighbor)
    zoom_in_nearest_neighbor zi_nn_inst (
        .clk(clock_25), .reset(reset_sync), .start(start_zi2),
        .rom_addr(rom_addr_zi2), .rom_data(proc_rom_q_out), 
        .ram_addr(ram_addr_zi2), .ram_data(ram_data_zi2), .ram_wren(ram_wren_zi2), .done(done_zi2)
    );
    
    // Instância 5: Zoom Out - Set 2 (Block Average)
    zoom_out_block_average zo_ba_inst (
        .clk(clock_25), .reset(reset_sync), .start(start_zo2),
        .rom_addr(rom_addr_zo2), .rom_data(proc_rom_q_out), 
        .ram_addr(ram_addr_zo2), .ram_data(ram_data_zo2), .ram_wren(ram_wren_zo2), .done(done_zo2)
    );

    // =================================================================
    // --- 4. ÁRBITRO DE MEMÓRIA E MÓDULOS CORE ---
    // =================================================================
    
    // Árbitro de Memória (Barramento Principal: VGA vs. Processador)
    memory_arbiter mem_arb_inst (
        .processing_active(control_processing_active), 
        .proc_ram_address(proc_ram_address),
        .proc_ram_wren(proc_ram_wren),
        .video_ram_address(video_ram_address),
        .final_ram_address(final_ram_address), 
        .final_ram_wren(final_ram_wren)        
    );

    // Módulo de Memória (RAM de trabalho e ROM de origem)
    memory_module mem_inst (
        .clock(clock_25), .reset(reset_sync),
        .ram_address(final_ram_address),
        .ram_data_in(proc_ram_data_in),
        .wren_in(final_ram_wren),
        .q_out_ram(ram_q_out),          // Saída para VGA
        .rom_address_ext(proc_rom_address),
        .q_out_rom(proc_rom_q_out)      // Saída para o Processador/Árbitro
    );

    // Controlador de Vídeo (Periférico de Saída)
    video_controller video_inst (
        .clk(clock_25),
        .reset(reset_sync),
        .display_mode(control_display_mode),
        .ram_data_in(ram_q_out), 
        .processing_active(control_processing_active), // Desliga tela no processamento
        .ram_addr_out(video_ram_address), 
        // Saídas VGA
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), .blue(blue),
        .sync(sync), .clk_out(clk_out), .blank(blank)
    );
    
    // Configuração de Parâmetro (Cor de Fundo)
    defparam video_inst.BACKGROUND_COLOR = SCREEN_COLOR;

endmodule