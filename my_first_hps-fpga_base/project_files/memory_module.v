// ================================================================================
// Módulo: memory_module.v
//
// Descrição:
// Este módulo atua como um invólucro (wrapper) para os dois blocos de memória
// RAM utilizados no projeto. Sua função é puramente estrutural, agrupando as
// duas instâncias de RAM (`ram_image` e `ram_op`) para simplificar a hierarquia
// do design e a instanciação no módulo `main.v`.
//
// Ele não contém lógica de controle ou arbitragem; apenas conecta as portas de
// entrada/saída deste módulo aos respectivos módulos de RAM internos.
//
// As duas RAMs são:
// 1. `ram_image`: Uma RAM de 19200 posições (160x120) x 8 bits. Armazena a
//    imagem original que é lida pelos algoritmos de processamento e escrita
//    pelo HPS durante o upload.
//
// 2. `ram_op`: Uma RAM de 307200 posições (640x480) x 8 bits. Armazena a
//    imagem processada, que é escrita pela `processing_unit` e lida pelo
//    `video_controller` para ser exibida na tela.
// ================================================================================

module memory_module(
    // --- Entradas Globais ---
    input  wire        clock,

    // --- Interface para a RAM da Imagem Original (`ram_image`) ---
    input  wire [14:0] image_address, // Endereço de 15 bits para acessar a ram_image (2^15 = 32768, suficiente para 160x120 = 19200).
    input  wire [7:0]  image_data_in, // Dados de 8 bits a serem escritos na ram_image.
    input  wire        image_wren,    // Sinal de habilitação de escrita (Write Enable) para a ram_image.
    output wire [7:0]  image_q_out,   // Saída de dados de 8 bits lidos da ram_image.

    // --- Interface para a RAM de Operação (`ram_op`) ---
    input  wire [18:0] op_address,    // Endereço de 19 bits para acessar a ram_op (2^19 = 524288, suficiente para 640x480 = 307200).
    input  wire [7:0]  op_data_in,    // Dados de 8 bits a serem escritos na ram_op.
    input  wire        op_wren,       // Sinal de habilitação de escrita (Write Enable) para a ram_op.
    output wire [7:0]  op_q_out       // Saída de dados de 8 bits lidos da ram_op.
);

    // --- Instância da RAM para a imagem original ---
    // Este é o bloco de memória que armazena a imagem de 160x120.
    // É gerado pelo MegaWizard do Quartus.
    ram_image inst_ram_image (
        .address (image_address), // Conecta a porta de endereço da interface à RAM.
        .clock   (clock),         // Conecta o clock global.
        .data    (image_data_in), // Conecta os dados de entrada.
        .wren    (image_wren),    // Conecta o sinal de escrita.
        .q       (image_q_out)    // Conecta a saída de dados.
    );

    // --- Instância da RAM para a imagem de operação/exibição ---
    // Este é o bloco de memória maior que armazena o resultado do processamento
    // para ser exibido pelo controlador VGA.
    ram_op inst_ram_op (
        .address (op_address),    // Conecta a porta de endereço da interface à RAM.
        .clock   (clock),         // Conecta o clock global.
        .data    (op_data_in),    // Conecta os dados de entrada.
        .wren    (op_wren),       // Conecta o sinal de escrita.
        .q       (op_q_out)       // Conecta a saída de dados.
    );

endmodule