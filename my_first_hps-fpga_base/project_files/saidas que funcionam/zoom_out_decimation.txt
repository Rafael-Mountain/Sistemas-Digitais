// Arquivo: zoom_out_decimation.v

module zoom_out_decimation (
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
    localparam RAM_WIDTH  = 160;
    
    // Estados internos
    localparam S_IDLE = 2'd0;
    localparam S_PROCESS = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state, next_state;

    reg [8:0] rom_x; // Contador para a largura da ROM
    reg [7:0] rom_y; // Contador para a altura da ROM
    
    // Contadores para o endereço da RAM
    reg [7:0] ram_x; // Precisa de 8 bits para 160
    reg [6:0] ram_y; // Precisa de 7 bits para 120

    reg pixel_valid; // Flag para indicar que um dado válido foi lido da ROM

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
            ram_x <= 0;
            ram_y <= 0;
            ram_wren <= 1'b0;
            pixel_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Por padrão, a escrita é desabilitada e o pixel_valid é resetado
            ram_wren <= 1'b0;
            pixel_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    rom_x <= 0;
                    rom_y <= 0;
                    ram_x <= 0;
                    ram_y <= 0;
                end
                
                S_PROCESS: begin
                    // No ciclo após um pedido de leitura, o dado é válido.
                    // Nós o escrevemos na RAM.
                    if (pixel_valid) begin
                        ram_wren <= 1'b1;
                        ram_data <= rom_data; // Escreve o dado que acabou de chegar
                        
                        // Avança os contadores
                        if (rom_x >= ROM_WIDTH - 2) begin
                            rom_x <= 0;
                            ram_x <= 0;
                            if (rom_y >= ROM_HEIGHT - 2) begin
                                rom_y <= 0; // Finalizado
                                ram_y <= 0;
                            end else begin
                                rom_y <= rom_y + 2; // Pula uma linha
                                ram_y <= ram_y + 1;
                            end
                        end else begin
                            rom_x <= rom_x + 2; // Pula um pixel
                            ram_x <= ram_x + 1;
                        end
                    end
                    
                    // Sinaliza que no próximo ciclo, um dado válido estará chegando.
                    // Isso controla o fluxo: 1 ciclo para ler, 1 ciclo para escrever.
                    pixel_valid <= 1'b1; 
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Lógica combinacional para o próximo estado e saídas
    always @(*) begin
        next_state = state;
        
        // --- Cálculo dos endereços de memória ---
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;
        
        // --- Transições de estado ---
        case (state)
            S_IDLE:
                if (start)
                    next_state = S_PROCESS;

            S_PROCESS:
                // Verifica se chegou ao final da imagem
                if (pixel_valid && (rom_x >= ROM_WIDTH - 2) && (rom_y >= ROM_HEIGHT - 2)) begin
                    next_state = S_DONE;
                end
                
            S_DONE:
                if (!start) // Volta para IDLE quando o comando 'start' for retirado
                    next_state = S_IDLE;
        endcase
    end

endmodule