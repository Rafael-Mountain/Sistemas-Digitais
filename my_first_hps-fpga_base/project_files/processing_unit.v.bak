module processing_unit (
    input wire clock,
    input wire reset,
    input wire algorithm_select, 
    input wire program_state,
    input wire [1:0] operation,

    input  wire [7:0]  rom_q_out_in,
    output wire [16:0] rom_addr_out,
    output wire [18:0] ram_addr_out,
    output wire [7:0]  ram_data_out,
    output wire        ram_wren_out,
    
    output wire processing_done
);

    localparam WAITING    = 1'b0;
    localparam PROCESSING = 1'b1;
    
    // Codificação das Operações
    localparam ORIGINAL = 2'b00;
    localparam ZOOM_OUT = 2'b01; 
    localparam ZOOM_IN  = 2'b10;
    localparam NONE     = 2'b11;
    

    // --- Geração dos Sinais de Start para os Sub-módulos ---
    // Note que ORIGINAL/COPY é tratado aqui com o mesmo 'start'
    wire start_original            = (program_state == PROCESSING) && (operation == ORIGINAL);
    
    wire start_zi_replication      = (program_state == PROCESSING) && (operation == ZOOM_IN)  && (!algorithm_select); 
    wire start_zo_decimation       = (program_state == PROCESSING) && (operation == ZOOM_OUT) && (!algorithm_select);
    
    wire start_zi_nearest_neighbor = (program_state == PROCESSING) && (operation == ZOOM_IN)  && (algorithm_select);
    wire start_zo_block_average    = (program_state == PROCESSING) && (operation == ZOOM_OUT) && (algorithm_select);
    
    // =================================================================
    // 2. FIOS INTERNOS PARA ARBITRAGEM (5 conjuntos)
    // =================================================================

    // Módulo Original (Cópia)
    wire [16:0] rom_addr_copy; wire [18:0] ram_addr_copy; wire [7:0] ram_data_copy;
    wire ram_wren_copy; wire done_copy;

    // Set 1: Replication (ZI) e Decimation (ZO)
    wire [16:0] rom_addr_zi1; wire [18:0] ram_addr_zi1; wire [7:0] ram_data_zi1;
    wire ram_wren_zi1; wire done_zi1;
    wire [16:0] rom_addr_zo1; wire [18:0] ram_addr_zo1; wire [7:0] ram_data_zo1;
    wire ram_wren_zo1; wire done_zo1;

    // Set 2: Nearest Neighbor (ZI) e Block Average (ZO)
    wire [16:0] rom_addr_zi2; wire [18:0] ram_addr_zi2; wire [7:0] ram_data_zi2;
    wire ram_wren_zi2; wire done_zi2;
    wire [16:0] rom_addr_zo2; wire [18:0] ram_addr_zo2; wire [7:0] ram_data_zo2;
    wire ram_wren_zo2; wire done_zo2;

    // ==============================
    // 3. INSTANCIAÇÃO DOS ALGORITMOS 
    // ==============================

    // Módulo de Cópia (Original/Copy)
    original original_inst (
        .clk(clock), .reset(reset), .start(start_original),
        .rom_addr(rom_addr_copy), .rom_data(rom_q_out_in),
        .ram_addr(ram_addr_copy), .ram_data(ram_data_copy), .ram_wren(ram_wren_copy),
        .done(done_copy)
    );

    // --- SET 1 ---
    zoom_in_replication zi_rep_inst (
        .clk(clock), .reset(reset), .start(start_zi_replication),
        .rom_addr(rom_addr_zi1), .rom_data(rom_q_out_in),
        .ram_addr(ram_addr_zi1), .ram_data(ram_data_zi1), .ram_wren(ram_wren_zi1),
        .done(done_zi1)
    );

    zoom_out_decimation zo_dec_inst (
        .clk(clock), .reset(reset), .start(start_zo_decimation),
        .rom_addr(rom_addr_zo1), .rom_data(rom_q_out_in),
        .ram_addr(ram_addr_zo1), .ram_data(ram_data_zo1), .ram_wren(ram_wren_zo1),
        .done(done_zo1)
    );
    
    // --- SET 2 ---
    zoom_in_nearest_neighbor zi_nn_inst (
        .clk(clock), .reset(reset), .start(start_zi_nearest_neighbor),
        .rom_addr(rom_addr_zi2), .rom_data(rom_q_out_in),
        .ram_addr(ram_addr_zi2), .ram_data(ram_data_zi2), .ram_wren(ram_wren_zi2),
        .done(done_zi2)
    );
    
    zoom_out_block_average zo_ba_inst (
        .clk(clock), .reset(reset), .start(start_zo_block_average),
        .rom_addr(rom_addr_zo2), .rom_data(rom_q_out_in),
        .ram_addr(ram_addr_zo2), .ram_data(ram_data_zo2), .ram_wren(ram_wren_zo2),
        .done(done_zo2)
    );

    // =================================================================
    // 4. LÓGICA DE ARBITRAGEM DE SAÍDA (MUX)
    // =================================================================
    
    // Arbitragem do Endereço da ROM
    assign rom_addr_out = (operation == ORIGINAL) ? rom_addr_copy :
                          (operation == ZOOM_IN)  ? (algorithm_select ? rom_addr_zi2 : rom_addr_zi1) :
                          (operation == ZOOM_OUT) ? (algorithm_select ? rom_addr_zo2 : rom_addr_zo1) : 17'd0;

    // Arbitragem do Endereço da RAM
    assign ram_addr_out = (operation == ORIGINAL) ? ram_addr_copy :
                          (operation == ZOOM_IN)  ? (algorithm_select ? ram_addr_zi2 : ram_addr_zi1) :
                          (operation == ZOOM_OUT) ? (algorithm_select ? ram_addr_zo2 : ram_addr_zo1) : 19'd0;

    // Arbitragem do Dado da RAM
    assign ram_data_out = (operation == ORIGINAL) ? ram_data_copy :
                          (operation == ZOOM_IN)  ? (algorithm_select ? ram_data_zi2 : ram_data_zi1) :
                          (operation == ZOOM_OUT) ? (algorithm_select ? ram_data_zo2 : ram_data_zo1) : 8'd0;

    // Arbitragem do Sinal de Escrita (WREN) da RAM
    assign ram_wren_out = (operation == ORIGINAL) ? ram_wren_copy :
                          (operation == ZOOM_IN)  ? (algorithm_select ? ram_wren_zi2 : ram_wren_zi1) :
                          (operation == ZOOM_OUT) ? (algorithm_select ? ram_wren_zo2 : ram_wren_zo1) : 1'b0;

    // Arbitragem do Sinal de Conclusão (DONE)
    assign processing_done  = (operation == ORIGINAL) ? done_copy :
                              (operation == ZOOM_IN)  ? (algorithm_select ? done_zi2 : done_zi1) :
                              (operation == ZOOM_OUT) ? (algorithm_select ? done_zo2 : done_zo1) : 1'b0;

endmodule
