module main (
    input  wire clk,            // Clock principal (50 MHz)
    input  wire reset_button,   // Botão de reset externo
    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk_out,
    output wire blank
);

    // --- Clock dividido para VGA ---
    wire nclk;  // 25 MHz
    Clock_25MHz clk_div_inst (
        .clk(clk),
        .nclk(nclk)
    );

    // --- Sinais VGA ---
    wire [9:0] next_x_internal;
    wire [9:0] next_y_internal;
    reg [7:0] color_in;

    // --- Sincroniza botão de reset com clock ---
    reg reset_sync;
    always @(posedge nclk) begin
        reset_sync <= reset_button;
    end

    // --- Instância do RAM access ---
    wire [7:0] ram_data_out;
    wire init_done;
    reg [18:0] ram_address;
    reg [7:0] ram_data_in;
    reg ram_wren;

    Ram_access ram_access_inst (
        .clock(nclk),
        .reset(reset_sync),
        .address(ram_address),
        .data_in(ram_data_in),
        .wren_in(ram_wren),
        .q_out(ram_data_out),
        .init_done(init_done)
    );

    // --- Instância do VGA ---
    vga_module vga_inst (
        .clock(~nclk),
        .reset(reset_sync),
        .color_in(color_in),
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

    // --- Offset para centralizar imagem ---
    localparam OFFSET_X = 160;
    localparam OFFSET_Y = 120;

    // --- Lógica de leitura da RAM para o VGA ---
    always @(posedge nclk) begin
        if (!init_done) begin
            // Enquanto RAM não estiver inicializada, tela preta
            color_in <= 8'd0;
            ram_address <= 19'd0;
            ram_data_in <= 8'd0;
            ram_wren <= 1'b0;
        end else begin
            // Quando RAM pronta, calcula endereço baseado no pixel
            if ((next_x_internal >= OFFSET_X) && (next_x_internal < OFFSET_X+320) &&
                (next_y_internal >= OFFSET_Y) && (next_y_internal < OFFSET_Y+240)) begin
                ram_address <= ((next_y_internal - OFFSET_Y) * 320) + (next_x_internal - OFFSET_X);
                color_in <= ram_data_out;
            end else begin
                ram_address <= 19'd0; // endereço qualquer fora da área
                color_in <= 8'd0;     // cor preta
            end

            // Nenhuma escrita externa neste exemplo
            ram_data_in <= 8'd0;
            ram_wren    <= 1'b0;
        end
    end

endmodule
