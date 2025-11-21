// ================================================================================
// Módulo: image_upload.v
//
// Descrição:
// Este módulo é projetado para lidar com a instrução de upload de imagem
// (opcode 111) enviada pelo HPS. Sua função é receber uma instrução que
// contém o endereço e o dado de um único pixel e escrever essa informação
// nas memórias RAM.
//
// Arquitetura e Funcionamento:
// O módulo é otimizado para ser extremamente rápido, executando sua tarefa
// em um único ciclo de clock.
// 1. Ao receber o sinal de `start`, ele decodifica a instrução de 32 bits
//    para extrair o endereço do pixel (`pixel_addr`) e seu valor (`pixel_data`).
// 2. Em um único ciclo, ele realiza uma escrita simultânea em AMBAS as memórias:
//    - `ram_image`: Atualiza a memória que armazena a imagem original.
//    - `ram_op`: Atualiza a memória de operação/exibição, garantindo que a
//                 mudança seja imediatamente visível na tela (após o
//                 processamento atual terminar).
// 3. O endereço para a `ram_op` é uma versão estendida com zeros do endereço
//    da `ram_image`, mapeando a imagem 160x120 para o canto superior esquerdo
//    da área de exibição de 640x480.
// 4. O sinal `done` é ativado no mesmo ciclo do `start`, informando à
//    `control_unit` que a operação foi concluída instantaneamente.
// ================================================================================

module image_upload (
    // --- Entradas ---
    input wire clk,                  // Clock do sistema (25MHz).
    input wire reset,                // Sinal de reset síncrono.
    input wire start,                // Sinal de ativação de um ciclo, vindo da `processing_unit`.
    input wire [31:0] instruction,   // A instrução completa de 32 bits vinda do HPS.

    // --- Saídas para a RAM da Imagem Original (`ram_image`) ---
    output reg [14:0] ram_image_addr, // Endereço do pixel a ser escrito.
    output reg [7:0]  ram_image_data, // Dado (cor) do pixel a ser escrito.
    output reg        ram_image_wren, // Habilitação de escrita.

    // --- Saídas para a RAM de Operação (`ram_op`) ---
    output reg [18:0] ram_op_addr,    // Endereço do pixel a ser escrito.
    output reg [7:0]  ram_op_data,    // Dado (cor) do pixel a ser escrito.
    output reg        ram_op_wren,    // Habilitação de escrita.

    // --- Saída de Status ---
    output reg        done              // Sinaliza que a operação terminou.
);

    // --- Decodificação da Instrução ---
    // Extrai o endereço do pixel (15 bits) e o dado do pixel (8 bits)
    // diretamente dos campos especificados na instrução.
    wire [14:0] pixel_addr = instruction[28:14];
    wire [7:0]  pixel_data = instruction[7:0];

    // --- Lógica Síncrona de Operação ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // No reset, garante que nenhuma escrita ocorra e que `done` esteja baixo.
            ram_image_wren <= 1'b0;
            ram_op_wren    <= 1'b0;
            done           <= 1'b0;
        end else begin
            if (start) begin
                // --- Ação em Ciclo Único ---
                // Quando `start` é ativado, todas as ações ocorrem neste mesmo ciclo.
                
                // Prepara os sinais para escrever na `ram_image`.
                ram_image_addr <= pixel_addr;
                ram_image_data <= pixel_data;
                ram_image_wren <= 1'b1;

                // Prepara os sinais para escrever na `ram_op`.
                // O endereço de 15 bits é estendido com zeros à esquerda para se
                // tornar um endereço de 19 bits, compatível com a `ram_op`.
                ram_op_addr    <= {4'b0, pixel_addr}; // Z-extend para 19 bits
                ram_op_data    <= pixel_data;
                ram_op_wren    <= 1'b1;
                
                // Sinaliza que a operação terminou imediatamente.
                done           <= 1'b1;
            end else begin
                // No ciclo seguinte ao `start`, desativa as escritas e o sinal `done`.
                // Isso garante que `ram_image_wren`, `ram_op_wren` e `done` sejam
                // pulsos de apenas um ciclo de duração.
                ram_image_wren <= 1'b0;
                ram_op_wren    <= 1'b0;
                done           <= 1'b0;
            end
        end
    end

endmodule