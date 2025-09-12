module main (
    input wire clk,        // Clock de entrada (pode ser 50 MHz ou outra frequência)
    output wire hsync,     // HSYNC para VGA
    output wire vsync,     // VSYNC para VGA
    output wire [7:0] red, // Cor vermelha
    output wire [7:0] green, // Cor verde
    output wire [7:0] blue,  // Cor azul
    output wire sync,      // Sync para VGA
    output wire clk_out,   // Clock para o VGA
    output wire blank      // Blank para VGA
);

    // Sinais internos
    wire nclk;                // Clock dividido de 25 MHz
    wire [9:0] next_x_internal;  // Coordenada X do próximo pixel
    wire [9:0] next_y_internal;  // Coordenada Y do próximo pixel
    reg [7:0] color_in; 
    reg [16:0] rom_address;      // Endereço para o ROM (17 bits)
    wire [7:0] rom_data;  

    Rom inst_rom (
        .address(rom_address),  // Endereço do ROM
        .clock(nclk),           // Clock do ROM (pode ser o mesmo nclk)
        .q(rom_data)            // Dados lidos do ROM
    );    

    // Instância do módulo Clock_25MHz
    Clock_25MHz clk_div_inst (
        .clk(clk),      // Clock de entrada (principal)
        .nclk(nclk)     // Clock dividido (25 MHz)
    );

    // Instância do módulo vga_module
    vga_module vga_inst (
        .clock(~nclk),            // Clock dividido de 25 MHz
        .reset(reset),           // Reset do sistema
        .color_in(color_in),     // Cor de entrada (RGB)
        .next_x(next_x_internal),// Coordenada X do próximo pixel
        .next_y(next_y_internal),// Coordenada Y do próximo pixel
        .hsync(hsync),           // HSYNC para VGA
        .vsync(vsync),           // VSYNC para VGA
        .red(red),               // Cor vermelha
        .green(green),           // Cor verde
        .blue(blue),             // Cor azul
        .sync(sync),             // Sync para VGA
        .clk(clk_out),           // Clock para VGA
        .blank(blank)            // Blank para VGA
    );
	 
    
    // Offset para centralizar a imagem (160 na horizontal e 120 na vertical)
    localparam OFFSET_X = 160;
    localparam OFFSET_Y = 120;

    always @(posedge nclk) begin
        // Adicionando o offset para centralizar a imagem
        rom_address <= ((next_y_internal - OFFSET_Y) * 320) + (next_x_internal - OFFSET_X);
        
        // Lógica para enviar a cor com base nas coordenadas
        if ((120 <= next_y_internal) && (next_y_internal <= 360) && (160 <= next_x_internal) && (next_x_internal <= 480)) begin
            color_in <= rom_data;  
        end else begin
            color_in <= 8'b00000000;  // Enviar a cor preta
        end
    end

endmodule
