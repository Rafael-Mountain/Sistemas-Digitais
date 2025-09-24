module zoom_in_replication (
    input  wire                      clock,
    input  wire                      reset,
    input  wire [15:0]               img_width,    // largura imagem original
    input  wire [15:0]               img_height,   // altura imagem original
    input  wire [7:0]                rom_data_in,  // pixel da ROM

    output reg  [16:0] rom_addr,     // endereço ROM
    output reg  [18:0] ram_addr,     // endereço RAM
    output reg  [7:0]                ram_data,     // dado RAM
    output reg                       ram_wren,     // enable escrita
    output reg                       done          // terminou
);

    // Contador que percorre pixels da imagem original
    reg [31:0] map_counter;  
    reg [1:0]  n_pixel;         // qual n_pixelrante (0..3)
    reg copying;

    // largura duplicada (para cálculo de endereços)
    wire [31:0] img_width2 = img_width << 1;

    always @(posedge clock) begin
        if (reset) begin
            rom_addr    <= 0;
            ram_addr    <= 0;
            ram_data    <= 0;
            ram_wren    <= 0;
            done        <= 0;
            map_counter <= 0;
            n_pixel        <= 0;
            copying     <= 1;
        end else if (copying) begin
            ram_wren <= 1'b1;
            ram_data <= rom_data_in;

            // cálculo do endereço baseado na fórmula dos n_pixelrantes
            case (n_pixel)
                2'd0: ram_addr <= ((map_counter * 2)    ) + ((map_counter / img_width) * img_width2);
                2'd1: ram_addr <= ((map_counter * 2) + 1) + ((map_counter / img_width) * img_width2);
                2'd2: ram_addr <= ((map_counter * 2)    ) + img_width2 + ((map_counter / img_width) * img_width2);
                2'd3: ram_addr <= ((map_counter * 2) + 1) + img_width2 + ((map_counter / img_width) * img_width2);
            endcase

            if (n_pixel < 2'd3) begin
                // ainda replicando o mesmo pixel
                n_pixel <= n_pixel + 1'b1;
            end else begin
                // terminou as 4 réplicas
                n_pixel <= 0;

                if (map_counter < (img_width * img_height) - 1) begin
                    map_counter <= map_counter + 1'b1;
                    rom_addr    <= rom_addr + 1'b1;
                end else begin
                    // terminou toda a imagem
                    copying <= 0;
                    done    <= 1'b1;
                    ram_wren <= 1'b0;
                end
            end
        end else begin
            ram_wren <= 1'b0; // idle
        end
    end

endmodule
