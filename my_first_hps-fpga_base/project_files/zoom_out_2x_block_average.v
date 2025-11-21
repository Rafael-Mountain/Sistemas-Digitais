// ================================================================================
// Módulo: zoom_out_2x_block_average.v
//
// Descrição:
// Este módulo aplica uma redução de 2x (zoom out) em uma imagem de 160x120,
// gerando uma imagem de 80x60. Ele utiliza o algoritmo de "Média de Bloco"
// (Block Average) para obter uma qualidade de imagem superior à da dizimação.
//
// Lógica de Operação:
// O módulo varre a imagem de *destino* (80x60). Para cada pixel de destino,
// ele executa os seguintes passos, controlados por uma máquina de estados (FSM):
// 1. Lê os 4 pixels correspondentes que formam um bloco 2x2 na imagem de origem.
//    - Ex: Para o pixel (x,y) de destino, ele lê os pixels (2x,2y), (2x+1,2y),
//      (2x,2y+1) e (2x+1,2y+1) da origem.
// 2. A FSM tem um estado de leitura para cada um desses 4 pixels (S_READ_00 a S_READ_11).
//    Os valores lidos são armazenados em registradores internos (p00, p01, p10, p11).
// 3. No estado S_CALC_WRITE, ele soma os 4 valores armazenados, divide o
//    resultado por 4 (usando deslocamento de bits `>> 2`) para calcular a média,
//    e escreve este novo valor de pixel na imagem de destino.
// 4. O processo é repetido para cada pixel da imagem de 80x60.
// ================================================================================

module zoom_out_2x_block_average (
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
    localparam RAM_WIDTH = 80, RAM_HEIGHT = 60;

    // --- Definição dos Estados da FSM ---
    // A FSM precisa de múltiplos estados para ler cada pixel do bloco 2x2.
    localparam S_IDLE=0, S_READ_00=1, S_READ_01=2, S_READ_10=3, S_READ_11=4, S_CALC_WRITE=5, S_DONE=6;
    reg [2:0] state, next_state;

    // --- Registradores de Controle e Dados ---
    reg [6:0] ram_x;          // Contador para a coordenada X da imagem de *destino* (0-79).
    reg [5:0] ram_y;          // Contador para a coordenada Y da imagem de *destino* (0-59).
    reg [7:0] p00, p01, p10, p11; // Buffers para armazenar os 4 pixels do bloco 2x2.
    reg [9:0] pixel_sum;      // Registrador para a soma. Precisa de 10 bits (4 * 255 = 1020).

    // --- Lógica Sequencial da FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    // --- Lógica Sequencial de Ações e Contadores ---
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0;
            p00 <= 0; p01 <= 0; p10 <= 0; p11 <= 0;
        end else begin
            ram_wren <= 1'b0; // A escrita só é ativa no estado S_CALC_WRITE.
            case (state)
                S_IDLE: begin done <= 1'b0; ram_x <= 0; ram_y <= 0; end
                S_READ_00: p00 <= rom_data; // Armazena o 1º pixel do bloco.
                S_READ_01: p01 <= rom_data; // Armazena o 2º pixel do bloco.
                S_READ_10: p10 <= rom_data; // Armazena o 3º pixel do bloco.
                S_READ_11: p11 <= rom_data; // Armazena o 4º pixel do bloco.
                S_CALC_WRITE: begin
                    ram_wren <= 1'b1;
                    pixel_sum = p00 + p01 + p10 + p11;
                    ram_data <= pixel_sum >> 2; // Calcula a média (divisão por 4).

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

        // Calcula o endereço de leitura da imagem de origem com base no estado atual.
        case(state)
            S_READ_00: rom_addr = ((ram_y*2)+0)*ROM_WIDTH + ((ram_x*2)+0); // Pixel (0,0) do bloco 2x2.
            S_READ_01: rom_addr = ((ram_y*2)+0)*ROM_WIDTH + ((ram_x*2)+1); // Pixel (1,0) do bloco 2x2.
            S_READ_10: rom_addr = ((ram_y*2)+1)*ROM_WIDTH + ((ram_x*2)+0); // Pixel (0,1) do bloco 2x2.
            S_READ_11: rom_addr = ((ram_y*2)+1)*ROM_WIDTH + ((ram_x*2)+1); // Pixel (1,1) do bloco 2x2.
            default:   rom_addr = 17'd0; // Endereço padrão para outros estados.
        endcase

        // --- Lógica de Transição de Estados ---
        case (state)
            S_IDLE:       if(start) next_state = S_READ_00;
            S_READ_00:    next_state = S_READ_01; // Sequência de leituras
            S_READ_01:    next_state = S_READ_10;
            S_READ_10:    next_state = S_READ_11;
            S_READ_11:    next_state = S_CALC_WRITE; // Após a última leitura, calcula e escreve.
            S_CALC_WRITE:
                // Se o último pixel de destino foi escrito...
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1)
                    next_state = S_DONE; // ...termina.
                else
                    next_state = S_READ_00; // ...senão, começa a ler o próximo bloco 2x2.
            S_DONE:       if (!start) next_state = S_IDLE;
        endcase
    end
endmodule