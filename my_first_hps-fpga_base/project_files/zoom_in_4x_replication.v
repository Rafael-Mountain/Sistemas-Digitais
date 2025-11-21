// ================================================================================
// Módulo: zoom_in_4x_replication.v
//
// Descrição:
// Este módulo implementa um algoritmo de zoom de 4x (aumento de 4 vezes)
// usando a técnica de "Replicação de Pixel". Ele lê uma imagem de origem de
// 160x120 e gera uma imagem de destino de 640x480.
//
// Algoritmo:
// O conceito é uma extensão do zoom 2x. Para cada pixel lido da imagem de
// origem, o módulo escreve um bloco de 4x4 pixels com o mesmo valor de cor na
// imagem de destino.
//
// Funcionamento:
// A máquina de estados (FSM) é muito semelhante à da versão 2x, mas o ciclo
// de escrita é mais longo. Para cada pixel da imagem de origem:
// 1. (S_READ_ROM): Lê o valor do pixel e o armazena em `pixel_buffer`.
// 2. (S_WRITE_RAM): Entra em um loop de 16 ciclos (controlado por `write_state`).
//    Em cada ciclo, escreve o valor do buffer em uma das dezesseis posições do
//    bloco 4x4 na RAM de destino.
// 3. Após escrever o bloco completo, avança para o próximo pixel da imagem de origem.
// 4. (S_DONE): Ao processar todos os pixels, sinaliza a conclusão.
// ================================================================================

module zoom_in_4x_replication (
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
    localparam RAM_WIDTH = 640;                  // Largura da imagem de destino.

    // --- Definição dos Estados da FSM ---
    localparam S_IDLE = 2'd0, S_READ_ROM = 2'd1, S_WRITE_RAM = 2'd2, S_DONE = 2'd3;
    reg [1:0] state, next_state;

    // --- Registradores de Controle e Dados ---
    reg [7:0] rom_x;        // Contador para a coordenada X da imagem de origem (0-159).
    reg [6:0] rom_y;        // Contador para a coordenada Y da imagem de origem (0-119).
    reg [3:0] write_state;  // Sub-contador (0-15) para os 16 pixels do bloco 4x4.
    reg [7:0] pixel_buffer; // Buffer para armazenar o pixel lido.

    // --- Lógica Sequencial da FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    // --- Lógica Sequencial de Ações e Contadores ---
    always @(posedge clk) begin
        if (reset) begin
            rom_x <= 0; rom_y <= 0; write_state <= 0;
            pixel_buffer <= 0; ram_wren <= 1'b0; done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    ram_wren <= 1'b0; done <= 1'b0;
                    rom_x <= 0; rom_y <= 0; write_state <= 0;
                end
                S_READ_ROM: begin
                    ram_wren <= 1'b0;
                    pixel_buffer <= rom_data; 
                end
                S_WRITE_RAM: begin
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer;
                    write_state <= write_state + 1'b1; // Avança o sub-contador do bloco 4x4.

                    if (write_state == 4'd15) begin // Se terminou de escrever o bloco 4x4...
                        // ... avança para o próximo pixel da imagem de origem.
                        if (rom_x == ROM_WIDTH - 1) begin
                            rom_x <= 0;
                            rom_y <= (rom_y == ROM_HEIGHT - 1) ? 0 : rom_y + 1'b1;
                        end else begin
                            rom_x <= rom_x + 1'b1;
                        end
                    end
                end
                S_DONE: begin
                    ram_wren <= 1'b0; done <= 1'b1;
                end
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços e Próximo Estado) ---
    always @(*) begin
        reg [1:0] sub_y, sub_x;
        next_state = state;
        
        // Calcula o endereço de leitura da imagem de origem.
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        
        // --- Cálculo do Endereço de Escrita ---
        // Converte o contador linear `write_state` (0-15) em coordenadas 2D
        // dentro do bloco 4x4 de destino.
        sub_y = write_state / 4; // Coordenada y relativa dentro do bloco (0-3).
        sub_x = write_state % 4; // Coordenada x relativa dentro do bloco (0-3).
        
        // Calcula o endereço final na RAM de destino:
        // 1. (rom_y * 4 + sub_y) -> Coordenada Y global na imagem de destino.
        // 2. (rom_x * 4 + sub_x) -> Coordenada X global na imagem de destino.
        ram_addr = ((rom_y * 4 + sub_y) * RAM_WIDTH) + (rom_x * 4 + sub_x);

        // --- Lógica de Transição de Estados ---
        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                if (write_state == 4'd15) begin // Se a escrita do bloco 4x4 terminou...
                    // ... verifica se a imagem inteira foi processada.
                    if (rom_x == ROM_WIDTH - 1 && rom_y == ROM_HEIGHT - 1)
                        next_state = S_DONE; // Se sim, conclui.
                    else
                        next_state = S_READ_ROM; // Se não, volta para ler o próximo pixel.
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule