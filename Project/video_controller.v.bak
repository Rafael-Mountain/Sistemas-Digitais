// Arquivo: video_controller.v
// Descrição: Módulo de vídeo CORRIGIDO com 'parameter' em vez de 'localparam'.

module video_controller (
    // --- Entradas de Controle ---
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  display_mode,
    input  wire [7:0]  ram_data_in,
    input  wire        processing_active,

    // --- Saída para a RAM ---
    output reg  [18:0] ram_addr_out,

    // --- Saídas Finais para o Conector VGA ---
    output wire        hsync,
    output wire        vsync,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,
    output wire        sync,
    output wire        clk_out,
    output wire        blank
);

    // --- PARÂMETROS ---
    // CORRIGIDO: Usando 'parameter' para permitir a modificação pelo módulo pai.
    parameter [7:0] BACKGROUND_COLOR = 8'h24; // Valor padrão
    
    // Parâmetros para o modo de exibição
    localparam D_ORIGINAL = 2'd0, D_ZOOM_IN = 2'd1, D_ZOOM_OUT = 2'd2;

    // Fios internos
    wire [9:0] vga_x, vga_y;
    wire [7:0] final_pixel_color;
    wire       is_in_image_area;

    // Lógica para determinar o tamanho e a posição da imagem (sem alterações)
    reg [15:0] current_img_width, current_img_height;
    always @(*) begin 
        case(display_mode)
            D_ZOOM_IN:  begin current_img_width = 16'd640; current_img_height = 16'd480; end
            D_ZOOM_OUT: begin current_img_width = 16'd160; current_img_height = 16'd120; end
            default:    begin current_img_width = 16'd320; current_img_height = 16'd240; end
        endcase
    end
    wire [9:0] offset_x = (640 - current_img_width) >> 1;
    wire [9:0] offset_y = (480 - current_img_height) >> 1;

    // Lógica principal de cálculo de endereço para a RAM (sem alterações)
    always @(posedge clk) begin
        if (reset) begin
            ram_addr_out <= 19'd0;
        end else begin
            if (is_in_image_area) begin
                ram_addr_out <= ((vga_y - offset_y) * current_img_width) + (vga_x - offset_x);
            end else begin
                ram_addr_out <= 19'd0; 
            end
        end
    end
    
    // Lógica combinacional para determinar a área da imagem
    assign is_in_image_area = (vga_x >= offset_x) && (vga_x < offset_x + current_img_width) &&
                              (vga_y >= offset_y) && (vga_y < offset_y + current_img_height);
                              
    // Lógica de cor aninhada
    assign final_pixel_color = processing_active ? BACKGROUND_COLOR : 
                               (is_in_image_area ? ram_data_in : BACKGROUND_COLOR);

    // Instância do gerador de sinais VGA (sem alterações)
    vga_module vga_inst (
        .clock(~clk),
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