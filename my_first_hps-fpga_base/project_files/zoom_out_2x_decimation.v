// ================================================================================
// Módulo: zoom_out_2x_decimation.v
//
// Descrição:
// Este módulo aplica uma redução de 2x (zoom out) em uma imagem de 160x120,
// gerando uma imagem de 80x60, usando o algoritmo de "Dizimação".
//
// Lógica de Operação:
// Dizimação é o processo de simplesmente descartar pixels. O módulo varre a
// imagem de *destino* (80x60) usando os contadores `ram_x` e `ram_y`. Para
// cada pixel de destino, ele:
// 1. Calcula o endereço do pixel correspondente na imagem de *origem*
//    multiplicando as coordenadas de destino por 2. Isso efetivamente "pula"
//    um pixel em cada direção (horizontal e vertical), lendo apenas os pixels
//    de coordenadas pares da imagem de origem.
// 2. Um pipeline de leitura-escrita de um ciclo é usado:
//    - O endereço da `ram_image` é calculado.
//    - No ciclo seguinte, o dado (`rom_data`) que chega é imediatamente escrito
//      na `ram_op`. Um flag (`pixel_valid`) gerencia este pipeline.
// 3. O processo se repete até que toda a imagem de destino de 80x60 seja
//    preenchida.
// ================================================================================

module zoom_out_2x_decimation (
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
    localparam ROM_WIDTH = 160, ROM_HEIGHT = 120; // Dimensões da imagem de origem.
    localparam RAM_WIDTH = 80;                   // Largura da imagem de destino.

    // --- Definição dos Estados da FSM ---
    localparam S_IDLE = 2'd0, S_PROCESS = 2'd1, S_DONE = 2'd2;
    reg [1:0] state, next_state;

    // --- Registradores de Controle ---
    reg [7:0] ram_x;          // Contador para a coordenada X da imagem de *destino* (0-79).
    reg [6:0] ram_y;          // Contador para a coordenada Y da imagem de *destino* (0-59).
    reg pixel_valid;      // Flag para gerenciar o pipeline de leitura de 1 ciclo.

    // --- Lógica Sequencial da FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end
    
    // --- Lógica Sequencial de Ações e Contadores ---
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0;
            pixel_valid <= 1'b0; done <= 1'b0;
        end else begin
            ram_wren <= 1'b0;
            pixel_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_PROCESS: begin
                    // O `pixel_valid` do ciclo anterior indica que `rom_data` agora contém um dado válido.
                    if (pixel_valid) begin
                        // Escreve o dado e avança para o próximo pixel de destino.
                        ram_wren <= 1'b1;
                        ram_data <= rom_data;
                        
                        if (ram_x == RAM_WIDTH - 1) begin
                            ram_x <= 0;
                            ram_y <= ram_y + 1;
                        end else begin
                            ram_x <= ram_x + 1;
                        end
                    end
                    // Ativa o flag para sinalizar que no *próximo* ciclo, um dado válido chegará.
                    // Isso inicia o pipeline de leitura para o próximo pixel.
                    pixel_valid <= 1'b1; 
                end
                S_DONE: done <= 1'b1;
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços e Próximo Estado) ---
    always @(*) begin
        next_state = state;
        
        // --- Cálculo do Endereço de Origem (Dizimação) ---
        // Para o pixel de destino (ram_y, ram_x), calcula o endereço correspondente na origem.
        // Multiplicar por 2 efetivamente lê apenas 1 a cada 2 pixels.
        rom_addr = ((ram_y * 2) * ROM_WIDTH) + (ram_x * 2);
        
        // Calcula o endereço de destino.
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;
        
        // --- Lógica de Transição de Estados ---
        case (state)
            S_IDLE: if (start) next_state = S_PROCESS;
            S_PROCESS:
                // A condição de término verifica se o *último* pixel (79, 59) foi escrito.
                // `ROM_HEIGHT/2 - 1` é 59.
                if (pixel_valid && ram_x == RAM_WIDTH - 1 && ram_y == ROM_HEIGHT/2 - 1) begin
                    next_state = S_DONE;
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule