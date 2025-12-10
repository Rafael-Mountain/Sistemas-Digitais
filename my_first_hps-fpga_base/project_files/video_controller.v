// ================================================================================
// Módulo: video_controller.v
//
// Alterações:
// - Adicionada entrada 'external_blank'.
// - Lógica de cor ajustada para forçar BACKGROUND_COLOR (Azul 0x24) se external_blank=1.
// ================================================================================

module video_controller (
    // --- Entradas ---
    input  wire         clk,
    input  wire         reset,
    input  wire [2:0]   display_mode,
    input  wire [7:0]   ram_data_in,
    input  wire         processing_active,
    
    // --- NOVA ENTRADA ---
    input  wire         external_blank, // 1 = Força tela de fundo (Blank via Software)

    // --- Saídas ---
    output reg  [18:0]  ram_addr_out,
    output wire         hsync, vsync,
    output wire [7:0]   red, green, blue,
    output wire         sync, clk_out, blank
);

    // Mantendo a cor original (Azul) conforme solicitado
    parameter [7:0] BACKGROUND_COLOR = 8'h24; 
    
    localparam D_ZOOM_OUT_4X = 3'b000;
    localparam D_ZOOM_OUT_2X = 3'b001;
    localparam D_ORIGINAL    = 3'b010;
    localparam D_ZOOM_IN_2X  = 3'b011;
    localparam D_ZOOM_IN_4X  = 3'b100;

    wire [9:0] vga_x, vga_y;
    wire [7:0] final_pixel_color;
    wire       is_in_image_area_comb;

    // --- Cálculo de Dimensões ---
    reg [9:0] current_img_width, current_img_height;
    always @(*) begin 
        case(display_mode)
            D_ZOOM_IN_4X:  begin current_img_width = 10'd640; current_img_height = 10'd480; end
            D_ZOOM_IN_2X:  begin current_img_width = 10'd320; current_img_height = 10'd240; end
            D_ZOOM_OUT_2X: begin current_img_width = 10'd80;  current_img_height = 10'd60;  end
            D_ZOOM_OUT_4X: begin current_img_width = 10'd40;  current_img_height = 10'd30;  end
            default:       begin current_img_width = 10'd160; current_img_height = 10'd120; end
        endcase
    end
    
    wire [9:0] offset_x = (640 - current_img_width) >> 1;
    wire [9:0] offset_y = (480 - current_img_height) >> 1;

    // --- PIPELINE DE 2 ESTÁGIOS ---
    reg is_in_image_area_d1, is_in_image_area_d2;
    reg processing_active_d1, processing_active_d2;
    // Precisamos pipelinar o blank externo também para manter sincronia? 
    // Como é um sinal "lento" de controle, não é estritamente crítico, mas vamos passar pelo pipeline.
    reg external_blank_d1, external_blank_d2;

    always @(posedge clk) begin
        if (reset) begin
            ram_addr_out <= 19'd0;
            is_in_image_area_d1 <= 1'b0; is_in_image_area_d2 <= 1'b0;
            processing_active_d1 <= 1'b1; processing_active_d2 <= 1'b1;
            external_blank_d1 <= 1'b0; external_blank_d2 <= 1'b0;
        end else begin
            // 1. Envia Endereço (Ciclo T)
            if (is_in_image_area_comb)
                ram_addr_out <= ((vga_y - offset_y) * current_img_width) + (vga_x - offset_x);
            else
                ram_addr_out <= 19'd0;

            // 2. Pipeline Estágio 1
            processing_active_d1 <= processing_active;
            is_in_image_area_d1 <= is_in_image_area_comb;
            external_blank_d1 <= external_blank;

            // 3. Pipeline Estágio 2 (O dado chega em T+2)
            processing_active_d2 <= processing_active_d1;
            is_in_image_area_d2 <= is_in_image_area_d1;
            external_blank_d2 <= external_blank_d1;
        end
    end
    
    // Verifica área da imagem (Combinacional)
    assign is_in_image_area_comb = (vga_x >= offset_x) && (vga_x < offset_x + current_img_width) &&
                                   (vga_y >= offset_y) && (vga_y < offset_y + current_img_height);
                                  
    // --- SELEÇÃO DE COR ---
    // Se external_blank estiver ativo OU processando hardware, mostra BACKGROUND_COLOR (Azul 0x24).
    assign final_pixel_color = (processing_active_d2 || external_blank_d2) ? BACKGROUND_COLOR : 
                               (is_in_image_area_d2 ? ram_data_in : BACKGROUND_COLOR);

    // Instância VGA
    vga_module vga_inst (
        .clock(clk), 
        .reset(reset), 
        .color_in(final_pixel_color),
        .next_x(vga_x), 
        .next_y(vga_y),
        .hsync(hsync), 
        .vsync(vsync), 
        .red(red), 
        .green(green), 
        .blue(blue),
        .sync(sync), 
        .clk(clk_out),
        .blank(blank)
    );

endmodule