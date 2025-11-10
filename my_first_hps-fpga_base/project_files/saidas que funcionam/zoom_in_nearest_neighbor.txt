// Arquivo: zoom_in_nearest_neighbor.v

module zoom_in_nearest_neighbor (
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
    localparam ROM_HEIGHT = 240;
    localparam RAM_WIDTH  = 640;
    localparam RAM_HEIGHT = 480;

    // Estados
    localparam S_IDLE       = 2'd0;
    localparam S_READ_ROM   = 2'd1;
    localparam S_WRITE_RAM  = 2'd2;
    localparam S_DONE       = 2'd3;

    reg [1:0] state, next_state;

    // Contadores para varrer a imagem de DESTINO (RAM)
    reg [9:0] ram_x; // Precisa de 10 bits para 640
    reg [8:0] ram_y; // Precisa de 9 bits para 480

    // Buffer para o dado da ROM
    reg [7:0] pixel_buffer;

    // FSM Principal
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Lógica sequencial (registradores)
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0;
            ram_y <= 0;
            ram_wren <= 1'b0;
            done <= 1'b0;
            pixel_buffer <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    ram_wren <= 1'b0;
                    ram_x <= 0;
                    ram_y <= 0;
                end
                
                S_READ_ROM: begin
                    ram_wren <= 1'b0;
                    pixel_buffer <= rom_data; // Armazena o dado que chegará da ROM
                end

                S_WRITE_RAM: begin
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer; // Escreve o dado armazenado

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
                    ram_wren <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Lógica combinacional
    always @(*) begin
        next_state = state;
        
        // Cálculo do endereço da ROM (Vizinho Mais Próximo)
        // Coordenada da ROM = Coordenada da RAM / 2
        rom_addr = ((ram_y >> 1) * ROM_WIDTH) + (ram_x >> 1);

        // O endereço de escrita na RAM é simplesmente o contador atual
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        // Lógica de transição de estados
        case (state)
            S_IDLE:
                if (start) next_state = S_READ_ROM;
            
            S_READ_ROM:
                next_state = S_WRITE_RAM;

            S_WRITE_RAM:
                // Se acabamos de escrever o último pixel
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_READ_ROM; // Volta para ler o próximo
                end

            S_DONE:
                if (!start) next_state = S_IDLE;
        endcase
    end
endmodule