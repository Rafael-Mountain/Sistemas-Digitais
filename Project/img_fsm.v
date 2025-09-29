module img_fsm (
    // Adicionar ao port list do img_fsm.v
    output wire [1:0]  current_state_out, // Saída do estado atual
    input  wire        clk,
    input  wire        reset,          
    input  wire        zoom_in_button, 
    input  wire        zoom_out_button,
    output reg [15:0]  image_width,    
    output reg [15:0]  image_height    
);
    localparam STATE_ORIGINAL = 2'b00;
    localparam // Renomeie o arquivo main.txt para main.v
module main (
    input  wire clk,
    input  wire reset_button,
    // Duas entradas de botão para o novo FSM
    input  wire zoom_in_button,
    input  wire zoom_out_button,
    input  wire [1:0]type, // Não utilizado
    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk_out,
    output wire blank
);
    // --- CLOCKS E RESETS ---
    wire nclk; // Clock de 25MHz para lógica principal e VGA
    Clock_25MHz clk_div_inst (.clk(clk), .nclk(nclk));

    wire pll_clk, pll_locked; // Clock rápido para memória
    pll pll_inst (.refclk(clk), .rst(~reset_button), .outclk_0(pll_clk), .locked(pll_locked));

    reg reset_sync;
    wire locked_nclk_domain;
    reg locked_sync1, locked_sync2;
    always @(posedge nclk) {locked_sync1, locked_sync2} <= {pll_locked, locked_sync1};
    assign locked_nclk_domain = locked_sync2;
    always @(posedge nclk) reset_sync <= ~reset_button | ~locked_nclk_domain;

    // --- SINAIS INTERNOS ---
    wire [9:0] next_x_internal, next_y_internal;
    wire [15:0] current_img_width, current_img_height;
    wire [9:0] offset_x, offset_y;

    // --- MÁQUINA DE ESTADOS DE IMAGEM (NOVO) ---
    img_fsm fsm_inst (
        .clk(nclk),
        .reset(reset_sync),
        .zoom_in_button(~zoom_in_button),  // Botões são ativo-baixo, FSM espera ativo-alto
        .zoom_out_button(~zoom_out_button),
        .image_width(current_img_width),
        .image_height(current_img_height)
    );

    // --- SINAIS DE INTERCONEXÃO E CDC ---
    reg  [18:0] mem_ram_addr_nclk;
    wire [7:0]  ram_data_out;
    wire        init_done_pllclk, init_done_nclk;
    
    reg [18:0] mem_ram_addr_sync1, mem_ram_addr_sync2;
    reg reset_sync_pll1, reset_sync_pll2;
    always @(posedge pll_clk) begin
        {reset_sync_pll1, reset_sync_pll2} <= {reset_sync, reset_sync_pll1};
        {mem_ram_addr_sync1, mem_ram_addr_sync2} <= {mem_ram_addr_nclk, mem_ram_addr_sync1};
    end
    wire reset_sync_pll = reset_sync_pll2;

    reg init_done_sync1, init_done_sync2;
    always @(posedge nclk) {init_done_sync1, init_done_sync2} <= {init_done_pllclk, init_done_sync1};
    assign init_done_nclk = init_done_sync2;
    
    // --- INSTÂNCIAS DOS MÓDULOS ---
    memory_module memory_access_inst (
        .clock(pll_clk),
        .reset(reset_sync_pll),
        .ram_address(mem_ram_addr_sync2),
        .ram_data_in(8'd0), // Apenas leitura após a inicialização
        .wren_in(1'b0),
        .q_out_ram(ram_data_out),
        .rom_address_ext(17'd0), // Sem acesso direto à ROM
        .q_out_rom(),
        .done(init_done_pllclk)
    );

    vga_module vga_inst (
        .clock(~nclk),
        .reset(reset_sync),
        .color_in(ram_data_out),
        .next_x(next_x_internal),
        .next_y(next_y_internal),
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), .blue(blue),
        .sync(sync), .clk(clk_out), .blank(blank)
    );

    // --- LÓGICA DE EXIBIÇÃO VGA DINÂMICA (NOVO) ---
    localparam SCREEN_WIDTH  = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam SOURCE_WIDTH  = 320; // A imagem na RAM é sempre 320x240

    // Calcula o offset para centralizar a imagem dinamicamente
    assign offset_x = (SCREEN_WIDTH - current_img_width) >> 1;
    assign offset_y = (SCREEN_HEIGHT - current_img_height) >> 1;

    // -------------------------
    // Instância do zoom_in_replication
    // -------------------------
    wire [8:0] zoom_x;
    wire [8:0] zoom_y;

    zoom_in_replication zoom_in_inst (
        .clk(nclk),
        .rst(reset_sync),
        .x_in(next_x_internal - offset_x),
        .y_in(next_y_internal - offset_y),
        .x_out(zoom_x),
        .y_out(zoom_y)
    );

    // -------------------------
    // Instância do zoom_out_Decimation
    // -------------------------
    wire [16:0] rom_addr_zoom_out;
    wire [18:0] ram_addr_zoom_out;
    wire [7:0]  ram_data_zoom_out;
    wire        ram_wren_zoom_out;
    wire        done_zoom_out;

    zoom_out_Decimation zoom_out_inst (
        .clock(nclk),
        .reset(reset_sync),
        .img_width(SOURCE_WIDTH),
        .img_height(240),
        .rom_data_in(ram_data_out),
        .rom_addr(rom_addr_zoom_out),
        .ram_addr(ram_addr_zoom_out),
        .ram_data(ram_data_zoom_out),
        .ram_wren(ram_wren_zoom_out),
        .done(done_zoom_out)
    );

    // -------------------------
    // Seleção do endereço final da RAM (modo atual)
    // -------------------------
    always @(posedge nclk) begin
        if (reset_sync || !init_done_nclk) begin
            mem_ram_addr_nclk <= 19'd0;
        end else begin
            if ((next_x_internal >= offset_x) && (next_x_internal < offset_x + current_img_width) &&
                (next_y_internal >= offset_y) && (next_y_internal < offset_y + current_img_height)) begin
                
                reg [9:0] relative_x;
                reg [9:0] relative_y;
                relative_x = next_x_internal - offset_x;
                relative_y = next_y_internal - offset_y;

                case (current_img_width)
                    16'd160: // Zoom Out → usa módulo
                        mem_ram_addr_nclk <= ram_addr_zoom_out;

                    16'd640: // Zoom In → usa módulo
                        mem_ram_addr_nclk <= (zoom_y * SOURCE_WIDTH) + zoom_x;
                        
                    default: // Normal 1:1
                        mem_ram_addr_nclk <= (relative_y * SOURCE_WIDTH) + relative_x;
                endcase
            end else begin
                mem_ram_addr_nclk <= 19'd0;
            end
        end
    end
endmodule
 = 2'b01;
    localparam STATE_ZOOM_IN  = 2'b10;
    
    reg [1:0] current_state;
    reg [1:0] next_state;
    
    reg zoom_in_sync1, zoom_in_sync2;
    always @(posedge clk) begin
        zoom_in_sync1 <= zoom_in_button;
        zoom_in_sync2 <= zoom_in_sync1;
    end
    wire zoom_in_pressed = ~zoom_in_sync2 & zoom_in_sync1;

    
    reg zoom_out_sync1, zoom_out_sync2;
    always @(posedge clk) begin
        zoom_out_sync1 <= zoom_out_button;
        zoom_out_sync2 <= zoom_out_sync1;
    end
    wire zoom_out_pressed = ~zoom_out_sync2 & zoom_out_sync1;
    
    
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_ORIGINAL;
        end else begin
            current_state <= next_state;
        end
    end
    
    always @(*) begin
        
        next_state = current_state;

        case (current_state)
            STATE_ORIGINAL: begin
                if (zoom_in_pressed) begin
                    next_state = STATE_ZOOM_IN;
                end else if (zoom_out_pressed) begin
                    next_state = STATE_ZOOM_OUT;
                end
            end
            
            STATE_ZOOM_OUT: begin
                if (zoom_in_pressed) begin
                    next_state = STATE_ORIGINAL;
                end
                
            end

            STATE_ZOOM_IN: begin
                if (zoom_out_pressed) begin
                    next_state = STATE_ORIGINAL;
                end
                
            end

            default: begin
                next_state = STATE_ORIGINAL;
            end
        endcase
    end

    
    
    always @(*) begin
        case (current_state)
            STATE_ORIGINAL: begin
                image_width  = 16'd320;
                image_height = 16'd240;
            end

            STATE_ZOOM_OUT: begin
                image_width  = 16'd160;
                image_height = 16'd120;
            end

            STATE_ZOOM_IN: begin
                image_width  = 16'd640;
                image_height = 16'd480;
            end
            
            default: begin
                image_width  = 16'd320;
                image_height = 16'd240;
            end
        endcase
    end

    // Adicionar no final do img_fsm.v
    assign current_state_out = current_state;
endmodule