// Renomeie o arquivo main.txt para main.v
module main (
    input  wire clk,
    input  wire reset_button,
    input  wire zoom_buttom, // O nome correto seria zoom_button
    input  wire [1:0]type,   // Não utilizado no código, mas mantido
    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk_out,
    output wire blank
);

    // --- Sinais e Clock ---
    wire nclk;
    Clock_25MHz clk_div_inst (
        .clk(clk),
        .nclk(nclk)
    );

    wire [9:0] next_x_internal;
    wire [9:0] next_y_internal;
    
    // --- Sincronização de Reset ---
    reg reset_sync;
    always @(posedge nclk) begin
        reset_sync <= ~reset_button; // Reset ativo em alto
    end

    // --- Sincronização e Detecção de Borda do Botão de Zoom ---
    reg zoom_sync1, zoom_sync2;
    always @(posedge nclk) begin
        zoom_sync1 <= ~zoom_buttom; // Botão ativo-baixo, sinal interno ativo-alto
        zoom_sync2 <= zoom_sync1;
    end
    wire zoom_pressed = ~zoom_sync2 & zoom_sync1; // Detector de borda de subida

    // --- Máquina de Estados (FSM) ---
    localparam S_INIT       = 2'd0; // Aguardando a cópia inicial ROM->RAM
    localparam S_IDLE       = 2'd1; // Ocioso, exibindo imagem, esperando por zoom
    localparam S_ZOOM_START = 2'd2; // Inicia o processo de zoom
    localparam S_ZOOM_WAIT  = 2'd3; // Aguardando o término do zoom

    reg [1:0] state;

    // --- Sinais de Interconexão dos Módulos ---
    // Interface para o memory_module
    wire [7:0]  ram_data_out;
    wire [7:0]  rom_data_out;
    wire        init_done;
    reg  [18:0] mem_ram_addr;
    reg  [7:0]  mem_ram_data_in;
    reg         mem_ram_wren;
    reg  [16:0] mem_rom_addr;

    // Interface para o zoom_in_replication
    wire [16:0] zoom_rom_addr;
    wire [18:0] zoom_ram_addr;
    wire [7:0]  zoom_ram_data;
    wire        zoom_ram_wren;
    wire        zoom_done;
    reg         zoom_reset;

    // --- Instanciação dos Módulos ---

    // Módulo de acesso à memória (gerencia RAM e ROM)
    memory_module memory_access_inst (
        .clock(nclk),
        .reset(reset_sync),         // Este reset dispara a cópia inicial
        .ram_address(mem_ram_addr),
        .ram_data_in(mem_ram_data_in),
        .wren_in(mem_ram_wren),
        .q_out_ram(ram_data_out),   // Saída da RAM para o VGA
        .rom_address_ext(mem_rom_addr),
        .q_out_rom(rom_data_out),   // Saída da ROM para o módulo de zoom
        .done(init_done)            // Sinaliza o fim da cópia inicial
    );

    // Módulo de Zoom por Replicação
    zoom_in_replication zoom_inst (
        .clock(nclk),
        .reset(zoom_reset),
        .img_width(16'd320),
        .img_height(16'd240),
        .rom_data_in(rom_data_out),
        .rom_addr(zoom_rom_addr),
        .ram_addr(zoom_ram_addr),
        .ram_data(zoom_ram_data),
        .ram_wren(zoom_ram_wren),
        .done(zoom_done)
    );

    // Módulo de Geração de Sinais VGA
    vga_module vga_inst (
        .clock(~nclk),
        .reset(reset_sync),
        .color_in(ram_data_out), // VGA sempre lê da RAM
        .next_x(next_x_internal),
        .next_y(next_y_internal),
        .hsync(hsync),
        .vsync(vsync),
        .red(red),
        .green(green),
        .blue(blue),
        .sync(sync),
        .clk(clk_out),
        .blank(blank)
    );

    // --- Lógica de Controle Central (FSM e Mux de Barramento) ---
    localparam OFFSET_X = 160;
    localparam OFFSET_Y = 120;
    localparam IMG_WIDTH_VGA_DISPLAY  = 320; // Largura da imagem a ser exibida
    localparam IMG_HEIGHT_VGA_DISPLAY = 240; // Altura da imagem a ser exibida

    always @(posedge nclk) begin
        if (reset_sync) begin
            state <= S_INIT;
        end else begin
            case (state)
                S_INIT: begin
                    if (init_done) begin
                        state <= S_IDLE;
                    end
                end

                S_IDLE: begin
                    if (zoom_pressed) begin
                        state <= S_ZOOM_START;
                    end
                end

                S_ZOOM_START: begin
                    state <= S_ZOOM_WAIT;
                end

                S_ZOOM_WAIT: begin
                    if (zoom_done) begin
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
    
    always @(posedge nclk) begin
        // Lógica de saída e controle do barramento baseada no estado
        case (state)
            S_INIT: begin
                // Aguardando, sem acesso externo à memória
                mem_ram_addr    <= 19'd0;
                mem_ram_data_in <= 8'd0;
                mem_ram_wren    <= 1'b0;
                mem_rom_addr    <= 17'd0;
                zoom_reset      <= 1'b1; // Mantém o módulo de zoom em reset
            end

            S_IDLE: begin
                // Modo de exibição: VGA lê da RAM
                zoom_reset <= 1'b1;

                // O VGA calcula o próximo endereço de pixel a ser lido
                // Exibe uma imagem de 320x240 centralizada na tela de 640x480
                if ((next_x_internal >= OFFSET_X) && (next_x_internal < OFFSET_X + IMG_WIDTH_VGA_DISPLAY) &&
                    (next_y_internal >= OFFSET_Y) && (next_y_internal < OFFSET_Y + IMG_HEIGHT_VGA_DISPLAY)) begin
                    mem_ram_addr <= ((next_y_internal - OFFSET_Y) * IMG_WIDTH_VGA_DISPLAY) + (next_x_internal - OFFSET_X);
                end else begin
                    mem_ram_addr <= 19'd0; // Área da borda
                end
                
                mem_ram_data_in <= 8'd0;
                mem_ram_wren    <= 1'b0; // Acesso de apenas leitura
                mem_rom_addr    <= 17'd0; // Sem acesso à ROM
            end

            S_ZOOM_START: begin
                // Reseta o módulo de zoom por um ciclo
                zoom_reset      <= 1'b1;
                mem_ram_addr    <= 19'd0;
                mem_ram_data_in <= 8'd0;
                mem_ram_wren    <= 1'b0;
                mem_rom_addr    <= 17'd0;
            end

            S_ZOOM_WAIT: begin
                // Modo de zoom: o módulo zoom_inst controla os barramentos
                zoom_reset <= 1'b0; // Libera o módulo de zoom do reset

                // Conecta as saídas do zoom_inst às entradas do memory_access_inst
                mem_rom_addr    <= zoom_rom_addr;
                mem_ram_addr    <= zoom_ram_addr;
                mem_ram_data_in <= zoom_ram_data;
                mem_ram_wren    <= zoom_ram_wren;
            end

            default: begin
                mem_ram_addr    <= 19'd0;
                mem_ram_data_in <= 8'd0;
                mem_ram_wren    <= 1'b0;
                mem_rom_addr    <= 17'd0;
                zoom_reset      <= 1'b1;
            end
        endcase
    end

endmodule