// ================================================================================
// Módulo: zoom_in_2x_replication.v
//
// Descrição:
// Este módulo implementa um algoritmo de zoom de 2x (aumento de 2 vezes)
// usando a técnica de "Replicação de Pixel". Ele lê uma imagem de origem de
// 160x120 e gera uma imagem de destino de 320x240.
//
// Algoritmo:
// Para cada pixel lido da imagem de origem, o módulo escreve um bloco de 2x2
// pixels com o mesmo valor de cor na imagem de destino.
//
// Funcionamento:
// Uma máquina de estados (FSM) controla o processo. Para cada pixel da imagem
// de origem:
// 1. (S_READ_ROM): Lê o valor do pixel e o armazena em um buffer (`pixel_buffer`).
// 2. (S_WRITE_RAM): Entra em um loop de 4 ciclos. Em cada ciclo, escreve o valor
//    do buffer em uma das quatro posições do bloco 2x2 na RAM de destino.
// 3. Após escrever o bloco, avança para o próximo pixel da imagem de origem.
// 4. (S_DONE): Ao processar todos os pixels, sinaliza a conclusão.
// ================================================================================

module zoom_in_2x_replication (
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
    localparam RAM_WIDTH = 320;                  // Largura da imagem de destino.

    // --- Definição dos Estados da FSM ---
    localparam S_IDLE = 2'd0, S_READ_ROM = 2'd1, S_WRITE_RAM = 2'd2, S_DONE = 2'd3;
    reg [1:0] state, next_state;

    // --- Registradores de Controle e Dados ---
    reg [7:0] rom_x;        // Contador para a coordenada X da imagem de origem (0-159).
    reg [6:0] rom_y;        // Contador para a coordenada Y da imagem de origem (0-119).
    reg [1:0] write_state;  // Sub-contador (0-3) para os 4 pixels a serem escritos no bloco 2x2.
    reg [7:0] pixel_buffer; // Buffer para armazenar o pixel lido enquanto ele é escrito 4 vezes.

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
                    // Estado de espera: zera contadores e desativa saídas.
                    ram_wren <= 1'b0; done <= 1'b0;
                    rom_x <= 0; rom_y <= 0; write_state <= 0;
                end
                S_READ_ROM: begin
                    // Estado de leitura: desativa a escrita e captura o dado
                    // da `ram_image` (que chega neste ciclo) no buffer.
                    ram_wren <= 1'b0;
                    pixel_buffer <= rom_data; 
                end
                S_WRITE_RAM: begin
                    // Estado de escrita: ativa a escrita e envia o dado do buffer.
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer;
                    // Avança o sub-contador do bloco 2x2.
                    write_state <= write_state + 1'b1;

                    if (write_state == 2'b11) begin // Se terminou de escrever o bloco 2x2...
                        // ... avança para o próximo pixel da imagem de origem.
                        if (rom_x == ROM_WIDTH - 1) begin // Se está no final da linha...
                            rom_x <= 0; // Volta para o início da próxima linha.
                            rom_y <= (rom_y == ROM_HEIGHT - 1) ? 0 : rom_y + 1'b1;
                        end else begin
                            rom_x <= rom_x + 1'b1; // Avança para o próximo pixel na mesma linha.
                        end
                    end
                end
                S_DONE: begin
                    // Estado de conclusão: desativa a escrita e ativa o sinal `done`.
                    ram_wren <= 1'b0; done <= 1'b1;
                end
            endcase
        end
    end

    // --- Lógica Combinacional (Cálculo de Endereços e Próximo Estado) ---
    always @(*) begin
        next_state = state;
        // Calcula o endereço de leitura da imagem de origem.
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        
        // Calcula o endereço de escrita na imagem de destino com base no sub-estado.
        case(write_state)
            2'b00: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2);      // Posição (0,0) do bloco 2x2
            2'b01: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2 + 1);  // Posição (1,0) do bloco 2x2
            2'b10: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2);  // Posição (0,1) do bloco 2x2
            default: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2 + 1); // Posição (1,1) do bloco 2x2
        endcase

        // Lógica de transição de estados.
        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                if (write_state == 2'b11) begin // Se a escrita do bloco 2x2 terminou...
                    // ... verifica se a imagem inteira foi processada.
                    if (rom_x == ROM_WIDTH - 1 && rom_y == ROM_HEIGHT - 1)
                        next_state = S_DONE; // Se sim, vai para o estado de conclusão.
                    else
                        next_state = S_READ_ROM; // Se não, volta para ler o próximo pixel.
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule