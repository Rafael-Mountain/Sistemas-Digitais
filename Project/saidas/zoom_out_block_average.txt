// Arquivo: zoom_out_block_average.v

module zoom_out_block_average (
    input wire clk,
    input wire reset,
    input wire start,

    // Interface com a ROM (Leitura)
    output reg  [16:0] rom_addr,
    input  wire [7:0]  rom_data,

    // Interface com a RAM (Escrita)
    output reg  [18:0] ram_addr,
    output reg  [7:0]  ram_data,
    output reg         ram_wren,

    output reg         done
);
    // Dimensões
    localparam ROM_WIDTH  = 320;
    localparam RAM_WIDTH  = 160;
    localparam RAM_HEIGHT = 120;

    // Estados
    localparam S_IDLE          = 3'd0;
    localparam S_READ_PIXEL_00 = 3'd1; // Lê pixel (x, y) do bloco
    localparam S_READ_PIXEL_01 = 3'd2; // Lê pixel (x+1, y)
    localparam S_READ_PIXEL_10 = 3'd3; // Lê pixel (x, y+1)
    localparam S_READ_PIXEL_11 = 3'd4; // Lê pixel (x+1, y+1)
    localparam S_CALC_AND_WRITE= 3'd5;
    localparam S_DONE          = 3'd6;

    reg [2:0] state, next_state;

    // Contadores para varrer a imagem de DESTINO (RAM)
    reg [7:0] ram_x; // Precisa de 8 bits para 160
    reg [6:0] ram_y; // Precisa de 7 bits para 120

    // Buffers para os 4 pixels lidos do bloco 2x2
    reg [7:0] p00, p01, p10, p11;
    reg [9:0] pixel_sum; // Soma pode chegar a 4*255=1020, precisa de 10 bits

    // FSM Principal
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Lógica sequencial
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0;
            ram_wren <= 1'b0; done <= 1'b0;
            p00 <= 0; p01 <= 0; p10 <= 0; p11 <= 0;
        end else begin
            ram_wren <= 1'b0; // Default
            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                
                S_READ_PIXEL_00: p00 <= rom_data; // Armazena o pixel (0,0)
                S_READ_PIXEL_01: p01 <= rom_data; // Armazena o pixel (0,1)
                S_READ_PIXEL_10: p10 <= rom_data; // Armazena o pixel (1,0)
                S_READ_PIXEL_11: p11 <= rom_data; // Armazena o pixel (1,1)

                S_CALC_AND_WRITE: begin
                    ram_wren <= 1'b1;
                    pixel_sum = p00 + p01 + p10 + p11;
                    ram_data <= pixel_sum >> 2; // Divide por 4

                    // Avança para o próximo pixel da RAM
                    if (ram_x == RAM_WIDTH - 1) begin
                        ram_x <= 0;
                        if (ram_y == RAM_HEIGHT - 1) begin
                            ram_y <= 0; // Terminou
                        end else begin
                            ram_y <= ram_y + 1;
                        end
                    end else begin
                        ram_x <= ram_x + 1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Lógica combinacional
    always @(*) begin
        next_state = state;

        // Endereço de escrita na RAM é sempre o mesmo durante o ciclo de leitura/escrita
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        // Seleciona qual dos 4 pixels do bloco ler, calculando o endereço diretamente
        case(state)
            S_READ_PIXEL_00: rom_addr = ((ram_y * 2) + 0) * ROM_WIDTH + ((ram_x * 2) + 0);
            S_READ_PIXEL_01: rom_addr = ((ram_y * 2) + 0) * ROM_WIDTH + ((ram_x * 2) + 1);
            S_READ_PIXEL_10: rom_addr = ((ram_y * 2) + 1) * ROM_WIDTH + ((ram_x * 2) + 0);
            S_READ_PIXEL_11: rom_addr = ((ram_y * 2) + 1) * ROM_WIDTH + ((ram_x * 2) + 1);
            default:         rom_addr = 17'd0;
        endcase

        // Lógica de transição de estados
        case (state)
            S_IDLE:           if(start) next_state = S_READ_PIXEL_00;
            S_READ_PIXEL_00:  next_state = S_READ_PIXEL_01;
            S_READ_PIXEL_01:  next_state = S_READ_PIXEL_10;
            S_READ_PIXEL_10:  next_state = S_READ_PIXEL_11;
            S_READ_PIXEL_11:  next_state = S_CALC_AND_WRITE;
            S_CALC_AND_WRITE:
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_READ_PIXEL_00;
                end
            S_DONE:
                if (!start) next_state = S_IDLE;
        endcase
    end
endmodule