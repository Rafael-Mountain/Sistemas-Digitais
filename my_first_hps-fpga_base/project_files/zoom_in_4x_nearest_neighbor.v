// ================================================================================
// Módulo: zoom_in_4x_nearest_neighbor.v
//
// Descrição:
// Este módulo aplica um zoom de 4x em uma imagem de 160x120, gerando uma imagem
// de 640x480, usando o algoritmo do "Vizinho Mais Próximo".
//
// Lógica de Operação:
// A lógica é uma extensão da versão 2x. O módulo varre sequencialmente cada
// pixel da imagem de *destino* (640x480) usando os contadores `ram_x` e `ram_y`.
// Para cada pixel de destino, ele:
// 1. Calcula o endereço do pixel correspondente na imagem de *origem*,
//    dividindo as coordenadas de destino por 4 (usando deslocamento de bits `>> 2`).
// 2. Uma máquina de estados otimizada gerencia o processo:
//    - No estado S_READ_ROM (implícito), o endereço de origem é enviado à memória.
//    - No estado S_WRITE_RAM (ciclo seguinte), o dado que chega da memória de
//      origem (`rom_data`) é imediatamente escrito na posição atual da memória
//      de destino (`ram_addr`).
// 3. O processo se repete até que toda a imagem de destino seja preenchida,
//    resultando em um fluxo contínuo de leitura e escrita.
// ================================================================================

module zoom_in_4x_nearest_neighbor (
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
    localparam RAM_WIDTH  = 640; // Largura da imagem de destino.
    localparam RAM_HEIGHT = 480; // Altura da imagem de destino.

    // --- Definição dos Estados da FSM ---
    // Esta FSM é otimizada e não usa um buffer explícito.
    localparam S_IDLE = 2'd0, S_READ_ROM = 2'd1, S_WRITE_RAM = 2'd2, S_DONE = 2'd3;
    reg [1:0] state;

    // --- Registradores de Controle ---
    reg [9:0] ram_x; // Contador para a coordenada X da imagem de *destino* (0-639).
    reg [8:0] ram_y; // Contador para a coordenada Y da imagem de *destino* (0-479).

    // --- Lógica Sequencial Unificada ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            ram_x <= 0; ram_y <= 0;
            ram_wren <= 1'b0; done <= 1'b0;
        end else begin
            // --- Lógica de Ações e Contadores ---
            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_wren <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_WRITE_RAM: begin
                    // Ativa a escrita e usa o dado `rom_data` que chegou neste ciclo.
                    ram_wren <= 1'b1;
                    ram_data <= rom_data;
                    
                    // Avança os contadores da imagem de destino.
                    if (ram_x == RAM_WIDTH - 1) begin
                        ram_x <= 0;
                        ram_y <= (ram_y == RAM_HEIGHT - 1) ? 0 : ram_y + 1;
                    end else begin
                        ram_x <= ram_x + 1;
                    end
                end
                S_DONE: begin
                    ram_wren <= 1'b0;
                    done <= 1'b1;
                end
                default: begin ram_wren <= 1'b0; end // S_READ_ROM, apenas espera.
            endcase
            
            // --- Lógica de Transição de Estados ---
            case (state)
                S_IDLE: if (start) state <= S_READ_ROM; // Começa o processo.
                S_READ_ROM: state <= S_WRITE_RAM; // Após pedir o dado, prepara para escrever.
                S_WRITE_RAM:
                    // Se o último pixel foi escrito...
                    if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1)
                        state <= S_DONE; // ...termina.
                    else
                        state <= S_READ_ROM; // ...senão, volta para pedir o próximo dado.
                S_DONE: if (!start) state <= S_IDLE;
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços) ---
    always @(*) begin
        // Calcula o endereço de origem com base nas coordenadas de destino atuais.
        // `>> 2` é uma divisão por 4.
        rom_addr = ((ram_y >> 2) * ROM_WIDTH) + (ram_x >> 2);
        
        // Calcula o endereço de destino.
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;
    end
endmodule