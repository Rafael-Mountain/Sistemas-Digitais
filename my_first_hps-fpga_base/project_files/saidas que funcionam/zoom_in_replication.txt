// Arquivo: zoom_in_replication.v

module zoom_in_replication (
    input wire clk,
    input wire reset,
    input wire start, // Sinal para iniciar o processamento

    // Interface com a ROM (Leitura)
    output reg  [16:0] rom_addr,
    input  wire [7:0]  rom_data, // Dado da ROM (com 1 ciclo de latência)

    // Interface com a RAM (Escrita)
    output reg  [18:0] ram_addr,
    output reg  [7:0]  ram_data,
    output reg         ram_wren,

    output reg         done // Sinaliza que o processamento terminou
);

    // Dimensões da imagem de origem (ROM)
    localparam ROM_WIDTH  = 320;
    localparam ROM_HEIGHT = 240;

    // Dimensões da imagem de destino (RAM)
    localparam RAM_WIDTH  = 640;
    
    // Estados internos
    localparam S_IDLE = 2'd0;
    localparam S_READ_ROM = 2'd1;
    localparam S_WRITE_RAM = 2'd2;
    localparam S_DONE = 2'd3;

    reg [1:0] state, next_state;

    reg [8:0] rom_x; // Contador para a largura da ROM (precisa de 9 bits para 320)
    reg [7:0] rom_y; // Contador para a altura da ROM (precisa de 8 bits para 240)
    
    reg [1:0] write_state; // Pequeno contador para os 4 pixels a serem escritos
    reg [7:0] pixel_buffer; // Armazena o pixel lido da ROM

    // Máquina de estados principal
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Lógica da FSM e contadores
    always @(posedge clk) begin
        if (reset) begin
            rom_x <= 0;
            rom_y <= 0;
            write_state <= 0;
            pixel_buffer <= 0;
            ram_wren <= 1'b0;
            done <= 1'b0;
        end else begin
            // Lógica para transição de estado e ações
            case (state)
                S_IDLE: begin
                    ram_wren <= 1'b0;
                    done <= 1'b0;
                    rom_x <= 0;
                    rom_y <= 0;
                    write_state <= 0;
                end
                
                S_READ_ROM: begin
                    ram_wren <= 1'b0;
                    // O dado lido (rom_data) estará disponível no próximo ciclo.
                    // Armazenamos no buffer para usar no estado S_WRITE_RAM.
                    pixel_buffer <= rom_data; 
                end

                S_WRITE_RAM: begin
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer; // Usa o pixel do buffer
                    
                    // Avança o sub-estado de escrita
                    write_state <= write_state + 1'b1;

                    // Quando os 4 pixels forem escritos, avança para o próximo pixel da ROM
                    if (write_state == 2'b11) begin
                        if (rom_x == ROM_WIDTH - 1) begin
                            rom_x <= 0;
                            if (rom_y == ROM_HEIGHT - 1) begin
                                rom_y <= 0; // Finalizado
                            end else begin
                                rom_y <= rom_y + 1'b1;
                            end
                        end else begin
                            rom_x <= rom_x + 1'b1;
                        end
                    end
                end

                S_DONE: begin
                    ram_wren <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Lógica combinacional para o próximo estado e saídas
    always @(*) begin
        next_state = state;
        
        // --- Cálculo dos endereços de memória ---
        // Endereço da ROM é sempre baseado em rom_x e rom_y
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        
        // Endereço da RAM depende do pixel da ROM e do sub-estado de escrita
        case(write_state)
            2'b00: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2);
            2'b01: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2 + 1);
            2'b10: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2);
            2'b11: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2 + 1);
        endcase

        // --- Transições de estado ---
        case (state)
            S_IDLE:
                if (start)
                    next_state = S_READ_ROM;
            
            S_READ_ROM:
                next_state = S_WRITE_RAM;

            S_WRITE_RAM:
                if (write_state == 2'b11) begin // Se a escrita do bloco 2x2 terminou
                    // Verifica se chegou ao final da imagem
                    if (rom_x == ROM_WIDTH - 1 && rom_y == ROM_HEIGHT - 1) begin
                        next_state = S_DONE;
                    end else begin
                        next_state = S_READ_ROM; // Volta para ler o próximo pixel
                    end
                end // Se não, continua no estado de escrita

            S_DONE:
                if (!start) // Volta para IDLE quando o comando 'start' for retirado
                    next_state = S_IDLE;
        endcase
    end

endmodule