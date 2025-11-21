// ================================================================================
// Módulo: processing_unit.v
//
// Descrição:
// Este módulo atua como a Unidade de Processamento (PU) do sistema. Ele não
// executa os algoritmos diretamente, mas sim gerencia e orquestra um conjunto
// de submódulos, cada um especializado em uma operação de imagem específica
// (zoom, cópia, upload, etc.).
//
// Funcionalidades Principais:
// 1. Recebe o comando de `operation` da `control_unit`.
// 2. Com base na `operation` e nos seletores de algoritmo (`zoom_in_algo_select`,
//    `zoom_out_algo_select`), ele ativa o submódulo correto enviando-lhe um
//    sinal de `start`. Apenas um submódulo é ativado por vez.
// 3. Contém instâncias de todos os algoritmos de processamento e do módulo
//    de upload de imagem.
// 4. Utiliza um grande multiplexador (`always @(*) case`) para arbitrar as
//    saídas de todos os submódulos. Ele seleciona os sinais de endereço, dados
//    e escrita do submódulo ativo e os roteia para as saídas da PU, que se
//    conectam às memórias (`ram_image` e `ram_op`).
// 5. Coleta o sinal `done` do submódulo ativo e o repassa para a `control_unit`
//    através da saída `processing_done`, sinalizando o término da operação.
// 6. Passa a instrução completa (`instruction_in`) para o módulo `image_upload`
//    quando essa operação é selecionada.
// ================================================================================

module processing_unit (
    // --- Entradas de Controle e Dados ---
    input wire clock,
    input wire reset,
    input wire        program_state,      // Sinal da `control_unit` (1 quando o processamento está ativo).
    input wire [2:0]  operation,          // Código da operação a ser executada.
    input wire [31:0] instruction_in,     // A instrução completa para o módulo de upload.
    input wire        zoom_in_algo_select,  // Seletor de algoritmo de zoom in.
    input wire        zoom_out_algo_select, // Seletor de algoritmo de zoom out.
    input wire [7:0]  ram_image_q_out_in, // Pixel lido da `ram_image` (imagem original).

    // --- Saídas para a `ram_image` ---
    output wire [14:0] ram_image_addr_out, // Endereço para ler/escrever na `ram_image`.
    output wire [7:0]  ram_image_data_out, // Dado a ser escrito na `ram_image` (usado pelo upload).
    output wire        ram_image_wren_out, // Habilitação de escrita para `ram_image` (usado pelo upload).
    
    // --- Saídas para a `ram_op` ---
    output wire [18:0] ram_op_addr_out,    // Endereço para escrever na `ram_op`.
    output wire [7:0]  ram_op_data_out,    // Dado do pixel processado a ser escrito na `ram_op`.
    output wire        ram_op_wren_out,    // Habilitação de escrita para `ram_op`.
    
    // --- Saída de Status ---
    output wire processing_done           // Sinaliza para a `control_unit` que a operação terminou.
);
    // --- Parâmetros e Constantes de Operação ---
    localparam PROCESSING = 1'b1;
    localparam ZOOM_OUT_4X = 3'b000, ZOOM_OUT_2X = 3'b001, ORIGINAL = 3'b010;
    localparam ZOOM_IN_2X  = 3'b011, ZOOM_IN_4X  = 3'b100, UPLOAD = 3'b101;

    // --- Lógica de Ativação (Start) dos Submódulos ---
    // Gera um sinal de `start` de um ciclo para o submódulo apropriado.
    // A combinação de `program_state`, `operation` e `algo_select` garante
    // que apenas um submódulo seja ativado de cada vez.
    wire start_original   = (program_state == PROCESSING) && (operation == ORIGINAL);
    wire start_zi_2x_rep  = (program_state == PROCESSING) && (operation == ZOOM_IN_2X)  && (!zoom_in_algo_select);
    wire start_zi_4x_rep  = (program_state == PROCESSING) && (operation == ZOOM_IN_4X)  && (!zoom_in_algo_select);
    wire start_zo_2x_dec  = (program_state == PROCESSING) && (operation == ZOOM_OUT_2X) && (!zoom_out_algo_select);
    wire start_zo_4x_dec  = (program_state == PROCESSING) && (operation == ZOOM_OUT_4X) && (!zoom_out_algo_select);
    wire start_zi_2x_nn   = (program_state == PROCESSING) && (operation == ZOOM_IN_2X)  && (zoom_in_algo_select);
    wire start_zi_4x_nn   = (program_state == PROCESSING) && (operation == ZOOM_IN_4X)  && (zoom_in_algo_select);
    wire start_zo_2x_ba   = (program_state == PROCESSING) && (operation == ZOOM_OUT_2X) && (zoom_out_algo_select);
    wire start_zo_4x_ba   = (program_state == PROCESSING) && (operation == ZOOM_OUT_4X) && (zoom_out_algo_select);
    wire start_upload     = (program_state == PROCESSING) && (operation == UPLOAD);

    // --- Fios de Saída de TODOS os Submódulos ---
    // Cada submódulo tem seu próprio conjunto de fios de saída. A lógica de
    // arbitragem (multiplexador) abaixo selecionará qual conjunto será
    // conectado às saídas reais do módulo `processing_unit`.
    wire [14:0] img_addr_copy; wire [18:0] op_addr_copy; wire [7:0] op_data_copy; wire op_wren_copy; wire done_copy;
    wire [14:0] img_addr_zi2x_rep; wire [18:0] op_addr_zi2x_rep; wire [7:0] op_data_zi2x_rep; wire op_wren_zi2x_rep; wire done_zi2x_rep;
    wire [14:0] img_addr_zi4x_rep; wire [18:0] op_addr_zi4x_rep; wire [7:0] op_data_zi4x_rep; wire op_wren_zi4x_rep; wire done_zi4x_rep;
    wire [14:0] img_addr_zo2x_dec; wire [18:0] op_addr_zo2x_dec; wire [7:0] op_data_zo2x_dec; wire op_wren_zo2x_dec; wire done_zo2x_dec;
    wire [14:0] img_addr_zo4x_dec; wire [18:0] op_addr_zo4x_dec; wire [7:0] op_data_zo4x_dec; wire op_wren_zo4x_dec; wire done_zo4x_dec;
    wire [14:0] img_addr_zi2x_nn; wire [18:0] op_addr_zi2x_nn; wire [7:0] op_data_zi2x_nn; wire op_wren_zi2x_nn; wire done_zi2x_nn;
    wire [14:0] img_addr_zi4x_nn; wire [18:0] op_addr_zi4x_nn; wire [7:0] op_data_zi4x_nn; wire op_wren_zi4x_nn; wire done_zi4x_nn;
    wire [14:0] img_addr_zo2x_ba; wire [18:0] op_addr_zo2x_ba; wire [7:0] op_data_zo2x_ba; wire op_wren_zo2x_ba; wire done_zo2x_ba;
    wire [14:0] img_addr_zo4x_ba; wire [18:0] op_addr_zo4x_ba; wire [7:0] op_data_zo4x_ba; wire op_wren_zo4x_ba; wire done_zo4x_ba;
    
    // Fios específicos para o módulo de upload
    wire [14:0] upload_img_addr; wire [7:0] upload_img_data; wire upload_img_wren;
    wire [18:0] upload_op_addr;  wire [7:0] upload_op_data;  wire upload_op_wren;
    wire done_upload;

    // =========================================================================
    // INSTÂNCIA DE TODOS OS SUBMÓDUTILOS DE PROCESSAMENTO DE IMAGEM
    // =========================================================================
    // Nota: O que antes era `.rom_data`/`.rom_addr` agora se refere à `ram_image`.
    //       O que antes era `.ram_*` agora se refere à `ram_op`.
    original original_inst(.clk(clock), .reset(reset), .start(start_original), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_copy), .ram_addr(op_addr_copy), .ram_data(op_data_copy), .ram_wren(op_wren_copy), .done(done_copy));
    zoom_in_2x_replication zi_2x_rep_inst(.clk(clock), .reset(reset), .start(start_zi_2x_rep), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zi2x_rep), .ram_addr(op_addr_zi2x_rep), .ram_data(op_data_zi2x_rep), .ram_wren(op_wren_zi2x_rep), .done(done_zi2x_rep));
    zoom_in_4x_replication zi_4x_rep_inst(.clk(clock), .reset(reset), .start(start_zi_4x_rep), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zi4x_rep), .ram_addr(op_addr_zi4x_rep), .ram_data(op_data_zi4x_rep), .ram_wren(op_wren_zi4x_rep), .done(done_zi4x_rep));
    zoom_out_2x_decimation zo_2x_dec_inst(.clk(clock), .reset(reset), .start(start_zo_2x_dec), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zo2x_dec), .ram_addr(op_addr_zo2x_dec), .ram_data(op_data_zo2x_dec), .ram_wren(op_wren_zo2x_dec), .done(done_zo2x_dec));
    zoom_out_4x_decimation zo_4x_dec_inst(.clk(clock), .reset(reset), .start(start_zo_4x_dec), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zo4x_dec), .ram_addr(op_addr_zo4x_dec), .ram_data(op_data_zo4x_dec), .ram_wren(op_wren_zo4x_dec), .done(done_zo4x_dec));
    zoom_in_2x_nearest_neighbor zi_2x_nn_inst(.clk(clock), .reset(reset), .start(start_zi_2x_nn), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zi2x_nn), .ram_addr(op_addr_zi2x_nn), .ram_data(op_data_zi2x_nn), .ram_wren(op_wren_zi2x_nn), .done(done_zi2x_nn));
    zoom_in_4x_nearest_neighbor zi_4x_nn_inst(.clk(clock), .reset(reset), .start(start_zi_4x_nn), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zi4x_nn), .ram_addr(op_addr_zi4x_nn), .ram_data(op_data_zi4x_nn), .ram_wren(op_wren_zi4x_nn), .done(done_zi4x_nn));
    zoom_out_2x_block_average zo_2x_ba_inst(.clk(clock), .reset(reset), .start(start_zo_2x_ba), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zo2x_ba), .ram_addr(op_addr_zo2x_ba), .ram_data(op_data_zo2x_ba), .ram_wren(op_wren_zo2x_ba), .done(done_zo2x_ba));
    zoom_out_4x_block_average zo_4x_ba_inst(.clk(clock), .reset(reset), .start(start_zo_4x_ba), .rom_data(ram_image_q_out_in), .rom_addr(img_addr_zo4x_ba), .ram_addr(op_addr_zo4x_ba), .ram_data(op_data_zo4x_ba), .ram_wren(op_wren_zo4x_ba), .done(done_zo4x_ba));
    
    // --- Instância para o Módulo de Upload ---
    image_upload upload_inst(
        .clk(clock), .reset(reset), .start(start_upload), .instruction(instruction_in),
        .ram_image_addr(upload_img_addr), .ram_image_data(upload_img_data), .ram_image_wren(upload_img_wren),
        .ram_op_addr(upload_op_addr), .ram_op_data(upload_op_data), .ram_op_wren(upload_op_wren),
        .done(done_upload)
    );

    // =========================================================================
    // LÓGICA DE ARBITRAGEM (MULTIPLEXADOR COMBINACIONAL)
    // =========================================================================
    // Este bloco `always @(*)` seleciona qual submódulo tem o controle das
    // saídas para as memórias, com base na `operation` atual.
    reg [14:0] ram_image_addr_out_reg;
    reg [7:0]  ram_image_data_out_reg;
    reg        ram_image_wren_out_reg;
    reg [18:0] ram_op_addr_out_reg;
    reg [7:0]  ram_op_data_out_reg;
    reg        ram_op_wren_out_reg;
    reg        processing_done_reg;

    always @(*) begin
        // Valores Padrão: Se nenhuma operação for selecionada, nenhuma ação é tomada.
        // As escritas são desabilitadas para segurança.
        ram_image_addr_out_reg = 15'd0; ram_image_data_out_reg = 8'd0; ram_image_wren_out_reg = 1'b0;
        ram_op_addr_out_reg    = 19'd0; ram_op_data_out_reg    = 8'd0; ram_op_wren_out_reg    = 1'b0;
        processing_done_reg    = 1'b0;

        case(operation)
            UPLOAD: begin
                // Roteia os sinais do módulo de upload
                ram_image_addr_out_reg = upload_img_addr;
                ram_image_data_out_reg = upload_img_data;
                ram_image_wren_out_reg = upload_img_wren;
                ram_op_addr_out_reg    = upload_op_addr;
                ram_op_data_out_reg    = upload_op_data;
                ram_op_wren_out_reg    = upload_op_wren;
                processing_done_reg    = done_upload;
            end
            ORIGINAL: begin
                // Roteia os sinais do módulo `original`
                ram_image_addr_out_reg = img_addr_copy;
                ram_op_addr_out_reg    = op_addr_copy;
                ram_op_data_out_reg    = op_data_copy;
                ram_op_wren_out_reg    = op_wren_copy;
                processing_done_reg    = done_copy;
            end
            ZOOM_IN_2X: if (zoom_in_algo_select) begin // Nearest Neighbor
                ram_image_addr_out_reg = img_addr_zi2x_nn; ram_op_addr_out_reg = op_addr_zi2x_nn;
                ram_op_data_out_reg = op_data_zi2x_nn; ram_op_wren_out_reg = op_wren_zi2x_nn;
                processing_done_reg = done_zi2x_nn;
            end else begin // Replication
                ram_image_addr_out_reg = img_addr_zi2x_rep; ram_op_addr_out_reg = op_addr_zi2x_rep;
                ram_op_data_out_reg = op_data_zi2x_rep; ram_op_wren_out_reg = op_wren_zi2x_rep;
                processing_done_reg = done_zi2x_rep;
            end
            ZOOM_IN_4X: if (zoom_in_algo_select) begin // Nearest Neighbor
                ram_image_addr_out_reg = img_addr_zi4x_nn; ram_op_addr_out_reg = op_addr_zi4x_nn;
                ram_op_data_out_reg = op_data_zi4x_nn; ram_op_wren_out_reg = op_wren_zi4x_nn;
                processing_done_reg = done_zi4x_nn;
            end else begin // Replication
                ram_image_addr_out_reg = img_addr_zi4x_rep; ram_op_addr_out_reg = op_addr_zi4x_rep;
                ram_op_data_out_reg = op_data_zi4x_rep; ram_op_wren_out_reg = op_wren_zi4x_rep;
                processing_done_reg = done_zi4x_rep;
            end
            ZOOM_OUT_2X: if (zoom_out_algo_select) begin // Block Average
                ram_image_addr_out_reg = img_addr_zo2x_ba; ram_op_addr_out_reg = op_addr_zo2x_ba;
                ram_op_data_out_reg = op_data_zo2x_ba; ram_op_wren_out_reg = op_wren_zo2x_ba;
                processing_done_reg = done_zo2x_ba;
            end else begin // Decimation
                ram_image_addr_out_reg = img_addr_zo2x_dec; ram_op_addr_out_reg = op_addr_zo2x_dec;
                ram_op_data_out_reg = op_data_zo2x_dec; ram_op_wren_out_reg = op_wren_zo2x_dec;
                processing_done_reg = done_zo2x_dec;
            end
            ZOOM_OUT_4X: if (zoom_out_algo_select) begin // Block Average
                ram_image_addr_out_reg = img_addr_zo4x_ba; ram_op_addr_out_reg = op_addr_zo4x_ba;
                ram_op_data_out_reg = op_data_zo4x_ba; ram_op_wren_out_reg = op_wren_zo4x_ba;
                processing_done_reg = done_zo4x_ba;
            end else begin // Decimation
                ram_image_addr_out_reg = img_addr_zo4x_dec; ram_op_addr_out_reg = op_addr_zo4x_dec;
                ram_op_data_out_reg = op_data_zo4x_dec; ram_op_wren_out_reg = op_wren_zo4x_dec;
                processing_done_reg = done_zo4x_dec;
            end
        endcase
    end
    
    // --- Atribuições Finais para as Saídas do Módulo ---
    // Conecta os registradores do bloco combinacional às portas de saída do módulo.
    assign ram_image_addr_out = ram_image_addr_out_reg;
    assign ram_image_data_out = ram_image_data_out_reg;
    assign ram_image_wren_out = ram_image_wren_out_reg;
    assign ram_op_addr_out    = ram_op_addr_out_reg;
    assign ram_op_data_out    = ram_op_data_out_reg;
    assign ram_op_wren_out    = ram_op_wren_out_reg;
    assign processing_done    = processing_done_reg;
endmodule