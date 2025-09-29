// main.v - Versão Final Completa
// Lógica de apagar a tela delegada ao módulo video_controller
module main (
    input  wire clk,                // Clock de 50MHz da placa
    input  wire reset_button,       // Botão de reset (ativo-baixo)
    input  wire zoom_in_button,    // Botão de zoom in (ativo-baixo)
    input  wire zoom_out_button,   // Botão de zoom out (ativo-baixo)
    input  wire algorithm_select,   // Chave: 0 para Set 1, 1 para Set 2

    // --- Saídas VGA ---
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
    // Cor de fundo para as bordas e para a tela durante o processamento.
    // Formato RRRGGGBB. Ex: Cinza escuro = 8'h24 (001 001 00)
    localparam [7:0] SCREEN_COLOR = 8'h24;
    
    // =================================================================
    // --- 1. CLOCKS E RESETS ---
    // =================================================================
    wire nclk; // Clock de 25MHz para VGA e lógica de controle
    Clock_25MHz clk_div_inst (.clk(clk), .nclk(nclk));

    wire pll_clk, pll_locked; // Clock rápido para memória (usado apenas para o sinal de 'locked')
    pll pll_inst (.refclk(clk), .rst(~reset_button), .outclk_0(pll_clk), .locked(pll_locked));

    reg reset_sync;
    always @(posedge nclk) begin
        reset_sync <= ~reset_button | ~pll_locked; 
    end
    
    // =================================================================
    // --- 2. FSM DE CONTROLE PRINCIPAL ---
    // =================================================================
    localparam S_IDLE       = 1'b0;
    localparam S_PROCESSING = 1'b1;
    reg state, next_state;

    // Registrador para armazenar a operação solicitada
    localparam OP_NONE     = 3'd0, OP_COPY = 3'd1, OP_ZOOM_IN = 3'd2, OP_ZOOM_OUT = 3'd3, OP_ORIGINAL = 3'd4;
    reg [2:0] processing_op;

    // Registrador para armazenar o modo de exibição atual
    localparam D_ORIGINAL = 2'd0, D_ZOOM_IN = 2'd1, D_ZOOM_OUT = 2'd2;
    reg [1:0] display_mode;
    
    // =================================================================
    // --- 3. DETECÇÃO DE BOTÕES ---
    // =================================================================
    wire zoom_in_signal           = ~zoom_in_button;
    reg  zoom_in_signal_r;
    reg  zoom_in_signal_r_anterior;
    wire zoom_out_signal          = ~zoom_out_button;
    reg  zoom_out_signal_r;
    reg  zoom_out_signal_r_anterior;

    always @(posedge nclk) begin
        zoom_in_signal_r           <= zoom_in_signal;
        zoom_in_signal_r_anterior  <= zoom_in_signal_r;
        zoom_out_signal_r          <= zoom_out_signal;
        zoom_out_signal_r_anterior <= zoom_out_signal_r;
    end
    wire zoom_in_pressed  = ~zoom_in_signal_r_anterior & zoom_in_signal_r;
    wire zoom_out_pressed = ~zoom_out_signal_r_anterior & zoom_out_signal_r;
    
    // =================================================================
    // --- 4. INSTÂNCIAS DOS MÓDULOS DE PROCESSAMENTO ---
    // =================================================================
    wire processing_done;
    wire [7:0] proc_rom_q_out;

    // --- Fios para o Módulo de Cópia ---
    wire [16:0] rom_addr_copy; wire [18:0] ram_addr_copy; wire [7:0] ram_data_copy;
    wire ram_wren_copy; wire done_copy;
    
    copy_rom_to_ram copy_inst (
        .clk(nclk), .reset(reset_sync), .start(state == S_PROCESSING && (processing_op == OP_COPY || processing_op == OP_ORIGINAL)),
        .rom_addr(rom_addr_copy), .rom_data(proc_rom_q_out),
        .ram_addr(ram_addr_copy), .ram_data(ram_data_copy), .ram_wren(ram_wren_copy),
        .done(done_copy)
    );

    // --- Fios e Instâncias para o SET 1 de Algoritmos (Replication / Decimation) ---
    wire [16:0] rom_addr_zi1; wire [18:0] ram_addr_zi1; wire [7:0] ram_data_zi1;
    wire ram_wren_zi1; wire done_zi1;
    wire [16:0] rom_addr_zo1; wire [18:0] ram_addr_zo1; wire [7:0] ram_data_zo1;
    wire ram_wren_zo1; wire done_zo1;
    
    zoom_in_replication zi_rep_inst (
        .clk(nclk), .reset(reset_sync), .start(state == S_PROCESSING && processing_op == OP_ZOOM_IN && !algorithm_select),
        .rom_addr(rom_addr_zi1), .rom_data(proc_rom_q_out),
        .ram_addr(ram_addr_zi1), .ram_data(ram_data_zi1), .ram_wren(ram_wren_zi1),
        .done(done_zi1)
    );
    zoom_out_decimation zo_dec_inst (
        .clk(nclk), .reset(reset_sync), .start(state == S_PROCESSING && processing_op == OP_ZOOM_OUT && !algorithm_select),
        .rom_addr(rom_addr_zo1), .rom_data(proc_rom_q_out),
        .ram_addr(ram_addr_zo1), .ram_data(ram_data_zo1), .ram_wren(ram_wren_zo1),
        .done(done_zo1)
    );

    // --- Fios e Instâncias para o SET 2 de Algoritmos (Nearest Neighbor / Block Average) ---
    wire [16:0] rom_addr_zi2; wire [18:0] ram_addr_zi2; wire [7:0] ram_data_zi2;
    wire ram_wren_zi2; wire done_zi2;
    wire [16:0] rom_addr_zo2; wire [18:0] ram_addr_zo2; wire [7:0] ram_data_zo2;
    wire ram_wren_zo2; wire done_zo2;

    zoom_in_nearest_neighbor zi_nn_inst (
        .clk(nclk), .reset(reset_sync), .start(state == S_PROCESSING && processing_op == OP_ZOOM_IN && algorithm_select),
        .rom_addr(rom_addr_zi2), .rom_data(proc_rom_q_out),
        .ram_addr(ram_addr_zi2), .ram_data(ram_data_zi2), .ram_wren(ram_wren_zi2),
        .done(done_zi2)
    );
    zoom_out_block_average zo_ba_inst (
        .clk(nclk), .reset(reset_sync), .start(state == S_PROCESSING && processing_op == OP_ZOOM_OUT && algorithm_select),
        .rom_addr(rom_addr_zo2), .rom_data(proc_rom_q_out),
        .ram_addr(ram_addr_zo2), .ram_data(ram_data_zo2), .ram_wren(ram_wren_zo2),
        .done(done_zo2)
    );
    
    // =================================================================
    // --- 5. ÁRBITRO DE MEMÓRIA (Processamento) ---
    // =================================================================
    wire [16:0] proc_rom_address; wire [18:0] proc_ram_address;
    wire [7:0]  proc_ram_data_in; wire proc_ram_wren;

    assign proc_rom_address = (processing_op == OP_COPY || processing_op == OP_ORIGINAL) ? rom_addr_copy :
                              (processing_op == OP_ZOOM_IN)                               ? (algorithm_select ? rom_addr_zi2 : rom_addr_zi1) :
                              (processing_op == OP_ZOOM_OUT)                              ? (algorithm_select ? rom_addr_zo2 : rom_addr_zo1) : 17'd0;

    assign proc_ram_address = (processing_op == OP_COPY || processing_op == OP_ORIGINAL) ? ram_addr_copy :
                              (processing_op == OP_ZOOM_IN)                               ? (algorithm_select ? ram_addr_zi2 : ram_addr_zi1) :
                              (processing_op == OP_ZOOM_OUT)                              ? (algorithm_select ? ram_addr_zo2 : ram_addr_zo1) : 19'd0;

    assign proc_ram_data_in = (processing_op == OP_COPY || processing_op == OP_ORIGINAL) ? ram_data_copy :
                              (processing_op == OP_ZOOM_IN)                               ? (algorithm_select ? ram_data_zi2 : ram_data_zi1) :
                              (processing_op == OP_ZOOM_OUT)                              ? (algorithm_select ? ram_data_zo2 : ram_data_zo1) : 8'd0;

    assign proc_ram_wren    = (processing_op == OP_COPY || processing_op == OP_ORIGINAL) ? ram_wren_copy :
                              (processing_op == OP_ZOOM_IN)                               ? (algorithm_select ? ram_wren_zi2 : ram_wren_zi1) :
                              (processing_op == OP_ZOOM_OUT)                              ? (algorithm_select ? ram_wren_zo2 : ram_wren_zo1) : 1'b0;

    assign processing_done  = (processing_op == OP_COPY || processing_op == OP_ORIGINAL) ? done_copy :
                              (processing_op == OP_ZOOM_IN)                               ? (algorithm_select ? done_zi2 : done_zi1) :
                              (processing_op == OP_ZOOM_OUT)                              ? (algorithm_select ? done_zo2 : done_zo1) : 1'b0;
    
    // =================================================================
    // --- 7. ÁRBITRO DE MEMÓRIA (VGA vs. Processador) ---
    // =================================================================
    wire [18:0] video_ram_address; // Endereço solicitado pelo controlador de vídeo
    wire [18:0] final_ram_address;
    wire        final_ram_wren;
    wire [7:0]  ram_q_out;         // Saída da RAM

    assign final_ram_address = (state == S_IDLE) ? video_ram_address : proc_ram_address;
    assign final_ram_wren    = (state == S_IDLE) ? 1'b0 : proc_ram_wren;
    
    // =================================================================
    // --- 8. INSTÂNCIAS DE MÓDULOS CORE ---
    // =================================================================
    memory_module mem_inst (
        .clock(nclk), .reset(reset_sync),
        .ram_address(final_ram_address),
        .ram_data_in(proc_ram_data_in),
        .wren_in(final_ram_wren),
        .q_out_ram(ram_q_out),
        .rom_address_ext(proc_rom_address),
        .q_out_rom(proc_rom_q_out),
        .done() 
    );

    video_controller video_inst (
        .clk(nclk),
        .reset(reset_sync),
        .display_mode(display_mode),
        .ram_data_in(ram_q_out),
        .processing_active(state == S_PROCESSING), // Informa ao controlador de vídeo o estado da FSM
        .ram_addr_out(video_ram_address),
        // Conexões diretas para as saídas VGA
        .hsync(hsync),
        .vsync(vsync),
        .red(red),
        .green(green),
        .blue(blue),
        .sync(sync),
        .clk_out(clk_out),
        .blank(blank)
    );
    // Sobrescreve o parâmetro de cor de fundo no video_controller
    defparam video_inst.BACKGROUND_COLOR = SCREEN_COLOR;
    
    // =================================================================
    // --- 9. LÓGICA DA FSM PRINCIPAL ---
    // =================================================================
    always @(posedge nclk or posedge reset_sync) begin
        if (reset_sync) begin
            state <= S_PROCESSING;
            processing_op <= OP_COPY;
            display_mode <= D_ORIGINAL;
        end else begin
            state <= next_state;

            if (state == S_IDLE && next_state == S_PROCESSING) begin
                if (zoom_in_pressed && display_mode != D_ORIGINAL)      processing_op <= OP_ORIGINAL;
                else if (zoom_out_pressed && display_mode != D_ORIGINAL)processing_op <= OP_ORIGINAL;
                else if (zoom_in_pressed && display_mode != D_ZOOM_IN)  processing_op <= OP_ZOOM_IN;
                else if (zoom_out_pressed && display_mode != D_ZOOM_OUT)processing_op <= OP_ZOOM_OUT;
                else                                                    processing_op <= OP_NONE;
            end

            if (state == S_PROCESSING && processing_done) begin
                case(processing_op)
                    OP_ZOOM_IN:  display_mode <= D_ZOOM_IN;
                    OP_ZOOM_OUT: display_mode <= D_ZOOM_OUT;
                    default:     display_mode <= D_ORIGINAL;
                endcase
            end
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            S_IDLE:
                if ((zoom_in_pressed && display_mode != D_ZOOM_IN) || (zoom_out_pressed && display_mode != D_ZOOM_OUT)) begin
                    next_state = S_PROCESSING;
                end

            S_PROCESSING:
                if (processing_done) begin
                    next_state = S_IDLE;
                end
        endcase
    end

    endmodule