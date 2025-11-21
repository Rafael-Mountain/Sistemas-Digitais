// ================================================================================
// Módulo: original.v
//
// Descrição:
// Este módulo é responsável por duas tarefas essenciais:
// 1. Copiar a imagem original de 160x120 pixels da memória de origem
//    (`ram_image`, aqui referida como ROM por convenção) para a memória de
//    operação/exibição (`ram_op`).
// 2. Limpar o restante da `ram_op` (a área fora da imagem 160x120) com a cor
//    preta (valor 0).
//
// Isso garante que, ao selecionar o modo "Original", a imagem de 160x120 seja
// posicionada no canto superior esquerdo da `ram_op` de 640x480, e o resto da
// memória de vídeo esteja limpo, evitando "lixo" visual na tela.
//
// Funcionamento:
// Ao receber o sinal `start`, o módulo inicia um processo sequencial. Um contador
// (`addr_counter`) varre todos os endereços da `ram_op` (de 0 a 307199).
// - Para os primeiros 19200 endereços, ele lê um pixel da `ram_image` e o
//   escreve no endereço correspondente da `ram_op`.
// - Para os endereços restantes, ele escreve o valor 0 (preto) na `ram_op`.
// Ao final, ele sinaliza a conclusão com o pulso `done`.
// ================================================================================

module original (
    // --- Entradas ---
    input wire clk,      // Clock do sistema (25MHz).
    input wire reset,    // Sinal de reset síncrono.
    input wire start,    // Pulso de um ciclo para iniciar a operação.
    input  wire [7:0]  rom_data, // Dado do pixel lido da `ram_image`.

    // --- Saídas para `ram_image` (leitura) ---
    output reg  [16:0] rom_addr, // Endereço de leitura para a `ram_image`. (17 bits para compatibilidade, mas apenas 15 são usados).

    // --- Saídas para `ram_op` (escrita) ---
    output reg  [18:0] ram_addr, // Endereço de escrita para a `ram_op`.
    output reg  [7:0]  ram_data, // Dado a ser escrito na `ram_op`.
    output reg         ram_wren, // Habilitação de escrita para a `ram_op`.
    
    // --- Saída de Status ---
    output reg         done      // Sinaliza que a operação de cópia/limpeza terminou.
);

    // --- Parâmetros ---
    localparam IMAGE_SIZE = 19200; // Tamanho total em pixels da imagem original (160 * 120).
    localparam RAM_SIZE_TO_CLEAR = 307200; // Tamanho total em pixels da `ram_op` (640 * 480).

    // --- Registradores Internos ---
    reg [18:0] addr_counter; // Contador principal para varrer todos os endereços da `ram_op`.
    reg processing;          // Flag que indica se a operação está em andamento.

    // --- Lógica Sequencial (Máquina de Estados Implícita) ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Estado inicial: tudo zerado e desativado.
            addr_counter <= 0;
            ram_wren <= 1'b0;
            done <= 1'b0;
            processing <= 1'b0;
        end else begin
            if (start && !processing) begin
                // Início da operação: ao receber `start`, ativa o flag `processing`
                // e zera o contador para começar do início.
                processing <= 1'b1;
                addr_counter <= 0;
                done <= 1'b0;
            end else if (processing) begin
                // Durante o processamento, a escrita na `ram_op` está sempre ativa.
                ram_wren <= 1'b1;
                
                if (addr_counter == RAM_SIZE_TO_CLEAR - 1) begin
                    // Fim da operação: se o contador atingiu o último endereço,
                    // desativa o flag `processing`, sinaliza `done` e desliga a escrita.
                    processing <= 1'b0;
                    done <= 1'b1;
                    ram_wren <= 1'b0;
                end else begin
                    // Continua o processo: incrementa o contador para o próximo endereço.
                    addr_counter <= addr_counter + 1;
                end
            end else begin
                 // Estado ocioso: mantém a escrita desligada e `done` em baixo.
                 ram_wren <= 1'b0;
                 done <= 1'b0;
            end
        end
    end

    // --- Lógica Combinacional (Geração de Endereços e Dados) ---
    always @(*) begin
        // O mesmo contador `addr_counter` é usado para gerar os endereços de
        // ambas as memórias.
        rom_addr = addr_counter[16:0]; // O endereço da `ram_image` é simplesmente os bits inferiores do contador.
        ram_addr = addr_counter;       // O endereço da `ram_op` é o valor completo do contador.

        // Lógica de seleção de dados:
        if (addr_counter < IMAGE_SIZE) begin
            // Se ainda estamos dentro da área da imagem original, o dado a ser
            // escrito na `ram_op` é o pixel vindo da `ram_image`.
            ram_data = rom_data;
        end else begin
            // Se já passamos da área da imagem, escrevemos 0 (preto) para
            // limpar o restante da memória de vídeo.
            ram_data = 8'd0;
        end
    end

endmodule