// ================================================================================
// Módulo: zoom_out_4x_block_average.v
//
// Descrição:
// Este módulo aplica uma redução de 4x (zoom out) em uma imagem de 160x120,
// gerando uma imagem de 40x30, utilizando o algoritmo de "Média de Bloco".
//
// Lógica de Operação:
// A lógica é uma versão ampliada do algoritmo de média 2x. Para cada pixel da
// imagem de *destino* (40x30), o módulo executa os seguintes passos:
// 1. Lê sequencialmente os 16 pixels correspondentes que formam um bloco 4x4
//    na imagem de origem.
// 2. Uma máquina de estados (FSM) com 18 estados principais controla o processo:
//    - 16 estados são usados para ler cada um dos 16 pixels do bloco. Os
//      valores lidos são armazenados em um array de registradores (`p_buf`).
//    - O 17º estado (S_CALC_WRITE) soma os 16 valores do buffer, divide o
//      resultado por 16 (usando `>> 4`) para obter a média, e escreve o
//      resultado na imagem de destino.
// 3. Após a escrita, o processo se repete para o próximo pixel da imagem de
//    destino, até que toda a imagem de 40x30 seja gerada.
// ================================================================================

module zoom_out_4x_block_average (
    // --- Entradas ---
    input wire clk, reset, start,
    input wire [7:0] rom_data, // Dado do pixel lido da `ram_image`.

    // --- Saídas para `ram_image` (leitura) ---
    output reg [16:0] rom_addr,   // Endereço de leitura da `ram_image`.

    // --- Saídas para `ram_op` (escrita) ---
    output reg [18:0] ram_addr,   // Endereço de escrita na `ram_op`.
    output reg [7:0]  ram_data,   // Dado a ser escrito na `ram_op`.
    output reg        ram_wren,   // Habilitação de escrita para a `ram_op`.
    
    // --- Saída de Status ---
    output reg        done
);
    // --- Parâmetros de Dimensão ---
    localparam ROM_WIDTH = 160;
    localparam RAM_WIDTH = 40;
    localparam RAM_HEIGHT = 30;

    // --- Definição dos Estados da FSM ---
    // A FSM usa o próprio valor do estado como um contador para os 16 ciclos de leitura.
    reg [5:0] state, next_state;
    localparam S_IDLE = 6'd0, S_CALC_WRITE = 6'd17, S_DONE = 6'd18;

    // --- Registradores de Controle e Dados ---
    reg [5:0] ram_x;          // Contador para a coordenada X da imagem de *destino* (0-39).
    reg [4:0] ram_y;          // Contador para a coordenada Y da imagem de *destino* (0-29).
    
    // Buffer para armazenar os 16 pixels do bloco 4x4.
    reg [7:0] p_buf [0:15];
    // Registrador para a soma. Precisa de 12 bits (16 * 255 = 4080).
    reg [11:0] pixel_sum;

    // --- Lógica Sequencial da FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    // --- Lógica Sequencial de Ações e Contadores ---
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0;
            pixel_sum <= 0;
        end else begin
            ram_wren <= 1'b0; // Escrita só é ativa no estado S_CALC_WRITE.
            
            // Durante os 16 estados de leitura (de 1 a 16)...
            if (state > S_IDLE && state < S_CALC_WRITE) begin
                // ...usa o valor do estado-1 como índice para salvar o pixel lido no buffer.
                p_buf[state-1] <= rom_data;
            end
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_CALC_WRITE: begin
                    // Soma todos os 16 pixels armazenados no buffer.
                    pixel_sum = p_buf[0] + p_buf[1] + p_buf[2] + p_buf[3] +
                                p_buf[4] + p_buf[5] + p_buf[6] + p_buf[7] +
                                p_buf[8] + p_buf[9] + p_buf[10] + p_buf[11] +
                                p_buf[12] + p_buf[13] + p_buf[14] + p_buf[15];
                    ram_data <= pixel_sum >> 4; // Calcula a média (divisão por 16).
                    ram_wren <= 1'b1;

                    // Avança para o próximo pixel de destino.
                    if (ram_x == RAM_WIDTH - 1) begin
                        ram_x <= 0;
                        ram_y <= (ram_y == RAM_HEIGHT - 1) ? 0 : ram_y + 1;
                    end else begin
                        ram_x <= ram_x + 1;
                    end
                end
                S_DONE: done <= 1'b1;
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços e Próximo Estado) ---
    always @(*) begin
        next_state = state;
        // Calcula o endereço de escrita na imagem de destino.
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        // --- Cálculo do Endereço de Leitura ---
        // Calcula o endereço do pixel no bloco 4x4 da imagem de origem.
        // O valor do estado (state-1) atua como um contador linear de 0 a 15.
        begin
            reg [1:0] rom_sub_y, rom_sub_x;
            rom_sub_y = (state-1) / 4; // Coordenada y relativa dentro do bloco 4x4.
            rom_sub_x = (state-1) % 4; // Coordenada x relativa dentro do bloco 4x4.
            rom_addr = ((ram_y * 4) + rom_sub_y) * ROM_WIDTH + ((ram_x * 4) + rom_sub_x);
        end
        
        // --- Lógica de Transição de Estados ---
        case (state)
            S_IDLE: if (start) next_state = S_IDLE + 1; // Começa a sequência de leituras.
            S_CALC_WRITE:
                // Se o último pixel de destino foi escrito...
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1)
                    next_state = S_DONE; // ...termina.
                else
                    next_state = S_IDLE + 1; // ...senão, começa a ler o próximo bloco 4x4.
            S_DONE: if (!start) next_state = S_IDLE;
            default: next_state = state + 1; // Avança pelos 16 estados de leitura.
        endcase
    end
endmodule