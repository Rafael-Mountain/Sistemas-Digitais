// ================================================================================
// Módulo: zoom_in_2x_nearest_neighbor.v
//
// Descrição:
// Este módulo aplica um zoom de 2x em uma imagem de 160x120, gerando uma imagem
// de 320x240, usando o algoritmo do "Vizinho Mais Próximo".
//
// Lógica de Operação:
// O módulo varre sequencialmente cada pixel da imagem de *destino* (320x240)
// usando os contadores `ram_x` e `ram_y`. Para cada pixel de destino:
// 1. Calcula o endereço do pixel correspondente na imagem de *origem*,
//    dividindo as coordenadas de destino por 2 (ex: `rom_addr = ((ram_y/2) * 160) + (ram_x/2)`).
// 2. Uma máquina de estados (FSM) gerencia um pipeline de leitura-escrita:
//    - No estado S_READ_ROM, envia o endereço calculado para a memória de origem.
//    - No estado S_WRITE_RAM, pega o dado que chegou da memória de origem e o
//      escreve na posição atual da memória de destino.
// 3. O processo se repete até que toda a imagem de destino seja preenchida.
// ================================================================================

module zoom_in_2x_nearest_neighbor (
    // --- Entradas ---
    input wire clk, reset, start,
    input  wire [7:0]  rom_data, // Dado do pixel lido da `ram_image`.

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
    localparam ROM_WIDTH  = 160; // Largura da imagem de origem.
    localparam RAM_WIDTH  = 320; // Largura da imagem de destino.
    localparam RAM_HEIGHT = 240; // Altura da imagem de destino.

    // --- Definição dos Estados da FSM ---
    localparam S_IDLE=2'd0, S_READ_ROM=2'd1, S_WRITE_RAM=2'd2, S_DONE=2'd3;
    reg [1:0] state, next_state;

    // --- Registradores de Controle e Dados ---
    reg [8:0] ram_x;          // Contador para a coordenada X da imagem de *destino* (0-319).
    reg [7:0] ram_y;          // Contador para a coordenada Y da imagem de *destino* (0-239).
    reg [7:0] pixel_buffer;   // Buffer para implementar o pipeline de leitura.

    // --- Lógica Sequencial da FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    // --- Lógica Sequencial de Ações e Contadores ---
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0; pixel_buffer <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    // Estado de espera: zera contadores e desativa saídas.
                    done <= 1'b0; ram_wren <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_READ_ROM: begin
                    // Estado de leitura: desativa a escrita e armazena o dado que
                    // chega da `ram_image` no buffer.
                    ram_wren <= 1'b0;
                    pixel_buffer <= rom_data;
                end
                S_WRITE_RAM: begin
                    // Estado de escrita: ativa a escrita, envia o dado do buffer
                    // e avança os contadores da imagem de destino.
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer;
                    if (ram_x == RAM_WIDTH - 1) begin // Se chegou ao final da linha...
                        ram_x <= 0; // Volta ao início da próxima linha.
                        ram_y <= (ram_y == RAM_HEIGHT - 1) ? 0 : ram_y + 1;
                    end else begin
                        ram_x <= ram_x + 1; // Avança para o próximo pixel na mesma linha.
                    end
                end
                S_DONE: begin
                    // Estado de conclusão: desativa escrita e ativa `done`.
                    ram_wren <= 1'b0; done <= 1'b1;
                end
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços e Próximo Estado) ---
    always @(*) begin
        next_state = state;
        
        // --- Cálculo do Endereço de Origem (Nearest Neighbor) ---
        // Para o pixel de destino (ram_y, ram_x), calcula o endereço correspondente na origem.
        // A operação `>> 1` é uma divisão por 2, encontrando o "vizinho mais próximo".
        rom_addr = ((ram_y >> 1) * ROM_WIDTH) + (ram_x >> 1);
        
        // Calcula o endereço de destino.
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        // --- Lógica de Transição de Estados ---
        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                // Se o último pixel (canto inferior direito) da imagem de destino foi escrito...
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1)
                    next_state = S_DONE; // ... a operação terminou.
                else
                    next_state = S_READ_ROM; // ... senão, volta para ler o dado do próximo pixel de destino.
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule