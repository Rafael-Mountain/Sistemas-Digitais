// ================================================================================
// Módulo: main.v
//
// Descrição:
// Este é o módulo de mais alto nível da lógica customizada na FPGA. Ele atua como
// um integrador central, conectando todos os sub-módulos do sistema de
// processamento de imagem.
//
// Arquitetura:
// 1. Recebe o clock principal (50MHz) e gera o clock de 25MHz para o VGA e a lógica.
// 2. Sincroniza as entradas assíncronas, como o botão de reset e o barramento de
//    instruções vindo do HPS, para evitar problemas de metastabilidade.
// 3. Implementa a unidade de controle (`control_unit`) que decodifica as instruções
//    e gerencia o estado do sistema (parado vs. processando).
// 4. Implementa a unidade de processamento (`processing_unit`) que executa os
//    algoritmos de imagem.
// 5. Gerencia o acesso às duas memórias RAM:
//    - `ram_image`: Armazena a imagem original de 160x120. Acessada para
//                   leitura pela `processing_unit` e para escrita pelo HPS
//                   (através do módulo de upload).
//    - `ram_op`: Armazena a imagem processada/exibida (até 640x480). O acesso a
//                ela é compartilhado (arbitrado) entre a `processing_unit` (para
//                escrita) e o `video_controller` (para leitura).
// 6. Controla o gerador de sinal VGA (`video_controller`) para exibir o conteúdo
//    da `ram_op`.
// 7. Fornece saídas de depuração para os displays de 7 segmentos e LEDs.
// ================================================================================

module main (
    // --- Entradas Globais ---
    input wire clock_50,        // Clock principal de 50MHz vindo da placa.
    input wire reset_button,    // Botão de reset físico (assíncrono).

    // --- Entradas do HPS e de Controle ---
    input wire [31:0] hps_pio_bus_in,       // Barramento de 32 bits do PIO do HPS, usado para enviar instruções.
    input wire        debug_display_select, // Chave (SW[0]) para selecionar qual parte da instrução exibir nos displays.

    // --- Saídas para o Controlador VGA ---
    output wire hsync,         // Sinal de sincronismo horizontal.
    output wire vsync,         // Sinal de sincronismo vertical.
    output wire [7:0] red, green, blue, // Dados de cor (formato RRRGGGBB).
    output wire sync, clk_out, blank,    // Outros sinais de controle VGA.
	 
    // --- Saídas de Debug para os LEDs ---
    output wire zoom_in_algo_select_wire,  // Indica o algoritmo de zoom in selecionado.
    output wire zoom_out_algo_select_wire, // Indica o algoritmo de zoom out selecionado.
	 
    // --- Saídas para os Displays de 7 Segmentos ---
    output wire [6:0] seg0_output, seg1_output, seg2_output,
    output wire [6:0] seg3_output, seg4_output, seg5_output
);

    //============================================================================
    // FIOS INTERNOS (WIRES)
    // Descrição: Sinais que conectam os diferentes sub-módulos.
    //============================================================================

    // --- Sinais de Clock e Reset ---
    wire clock_25;     // Clock de 25MHz, derivado do `clock_50`, para a lógica e o VGA.
    wire reset_sync;   // Sinal de reset, sincronizado com o `clock_25`.
    
    // --- Barramento de Instrução ---
    wire [31:0] hps_pio_bus_sync; // Versão sincronizada do barramento de instruções do HPS.
    
    // --- Fios de Controle do Sistema ---
    wire program_state;      // Sinal da `control_unit`: 0 = WAITING (esperando instrução), 1 = PROCESSING (executando).
    wire processing_done;    // Pulso da `processing_unit` para a `control_unit` indicando que a operação terminou.
    wire instruction_strobe; // Pulso que indica a chegada de uma nova instrução do HPS.
    wire [2:0] operation;    // Código da operação (ex: ZOOM_IN_2X) que a `processing_unit` deve executar.
    wire [2:0] display_mode; // Modo de exibição (ex: 160x120, 320x240) para o `video_controller`.
    
    // --- Fios de Seleção de Algoritmo ---
    wire zoom_in_algo_select;  // 0 = Replication, 1 = Nearest Neighbor.
    wire zoom_out_algo_select; // 0 = Decimation, 1 = Block Average.

    // --- Fios para a Interface da `ram_image` (Imagem Original) ---
    // A `processing_unit` é a única que controla esta RAM para leitura.
    wire [14:0] proc_img_addr;    // Endereço de leitura gerado pela `processing_unit`.
    wire [7:0]  proc_img_data_in; // Dados de escrita (não usado pela PU, apenas pelo upload).
    wire        proc_img_wren;    // Habilitação de escrita (não usado pela PU, apenas pelo upload).
    wire [7:0]  img_q_out;        // Dado lido da `ram_image` e enviado para a `processing_unit`.

    // --- Fios para a Interface da `ram_op` (Imagem de Operação) ---
    // O acesso a esta RAM é compartilhado entre a PU (escrita) e o Video Controller (leitura).
    wire [18:0] proc_op_addr;       // Endereço de escrita gerado pela `processing_unit`.
    wire [18:0] video_ram_address;  // Endereço de leitura gerado pelo `video_controller`.
    wire [18:0] final_op_addr;      // Endereço final (selecionado pelo árbitro) enviado à RAM.
    wire [7:0]  proc_op_data_in;    // Dados de escrita gerados pela `processing_unit`.
    wire        proc_op_wren;       // Sinal de escrita gerado pela `processing_unit`.
    wire        final_op_wren;      // Sinal de escrita final (selecionado pelo árbitro).
    wire [7:0]  op_q_out;           // Dado lido da `ram_op` e enviado para o `video_controller`.

    //============================================================================
    // INSTÂNCIA DOS MÓDULOS
    //============================================================================

    //----------------------------------------------------------------------------
    // Seção 1: Módulos Base e Sincronizadores
    // Geram os sinais de clock e reset estáveis e sincronizam as entradas externas.
    //----------------------------------------------------------------------------
    clock_divider clock_divider_inst (.clock_in(clock_50), .clock_out(clock_25));
    sync_reset_button sync_reset_button_inst (.clock(clock_25), .reset_button_in(reset_button), .reset_sync_out(reset_sync));

    // Sincronizador de 2 estágios para o barramento do HPS. Essencial para
    // transferir dados de forma segura do domínio de clock do HPS para o
    // domínio de clock da FPGA (`clock_25`).
    synchronizer #( .WIDTH(32) ) pio_bus_synchronizer (
        .clk(clock_25),
        .reset(reset_sync),
        .data_in(hps_pio_bus_in),
        .data_out(hps_pio_bus_sync)
    );

    //----------------------------------------------------------------------------
    // Seção 2: Núcleo de Processamento de Imagem
    // Contém os módulos que formam a lógica principal do sistema.
    //----------------------------------------------------------------------------

    // Detecta uma mudança no barramento de instrução e gera um pulso (`instruction_strobe`).
    // Isso age como uma "campainha" para a `control_unit`.
    instruction_strobe_detector strobe_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .instruction_bus(hps_pio_bus_sync),
        .strobe_out(instruction_strobe)
    );

    // A "mente" do sistema. Decodifica instruções, controla a máquina de estados
    // principal (WAITING/PROCESSING) e dita o que os outros módulos devem fazer.
    control_unit control_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .instruction_in(hps_pio_bus_sync),
        .instruction_strobe(instruction_strobe),
        .processing_done(processing_done),
        .program_state(program_state), 
        .operation(operation),
        .display_mode(display_mode),
        .zoom_in_algo_select(zoom_in_algo_select),
        .zoom_out_algo_select(zoom_out_algo_select)
    );
    
    // O "músculo" do sistema. Recebe um comando de `operation` da `control_unit`
    // e executa o algoritmo de processamento de imagem correspondente.
    processing_unit processing_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .program_state(program_state),
        .operation(operation),
        .instruction_in(hps_pio_bus_sync),
        .zoom_in_algo_select(zoom_in_algo_select),
        .zoom_out_algo_select(zoom_out_algo_select),
        .ram_image_q_out_in(img_q_out),
        .ram_image_addr_out(proc_img_addr),
        .ram_image_data_out(proc_img_data_in),
        .ram_image_wren_out(proc_img_wren),
        .ram_op_addr_out(proc_op_addr),
        .ram_op_data_out(proc_op_data_in),
        .ram_op_wren_out(proc_op_wren),
        .processing_done(processing_done)
    );
    
    // --- ÁRBITRO DE ACESSO PARA A RAM DE OPERAÇÃO (`ram_op`) ---
    // Lógica simples (multiplexador) que decide quem controla a `ram_op`.
    // Se `program_state` é 1 (PROCESSING), a `processing_unit` tem controle para escrever.
    // Se `program_state` é 0 (WAITING), o `video_controller` tem controle para ler.
    assign final_op_addr = (program_state == 1'b1) ? proc_op_addr : video_ram_address;
    assign final_op_wren = (program_state == 1'b1) ? proc_op_wren : 1'b0;

    // Módulo que encapsula as duas memórias RAM (`ram_image` e `ram_op`).
    memory_module mem_inst (
        .clock(clock_25), 
        .image_address(proc_img_addr),
        .image_data_in(proc_img_data_in),
        .image_wren(proc_img_wren),
        .image_q_out(img_q_out),
        .op_address(final_op_addr),
        .op_data_in(proc_op_data_in),
        .op_wren(final_op_wren),
        .op_q_out(op_q_out)
    );

    // Gera os sinais de sincronismo VGA e lê os dados de pixel da `ram_op`
    // para exibi-los na tela. Centraliza a imagem com base no `display_mode`.
    video_controller video_inst (
        .clk(clock_25),
        .reset(reset_sync),
        .display_mode(display_mode),
        .ram_data_in(op_q_out),
        .processing_active(program_state), 
        .ram_addr_out(video_ram_address),   
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), 
        .blue(blue), .sync(sync), .clk_out(clk_out), .blank(blank)
    );

    //----------------------------------------------------------------------------
    // Seção 3: Saídas de Debug e Display de 7 Segmentos
    //----------------------------------------------------------------------------
    
    // Expõe os fios internos de seleção de algoritmo para as portas de saída do
    // módulo, permitindo que sejam conectados a LEDs para depuração visual.
    assign zoom_in_algo_select_wire = zoom_in_algo_select;
    assign zoom_out_algo_select_wire = zoom_out_algo_select;

    // Controla os displays de 7 segmentos para mostrar o valor hexadecimal
    // da instrução atualmente no barramento do HPS.
    top_module seven_segment_controller_inst (
        .hps_pio_data   (hps_pio_bus_sync),
        .display_select (debug_display_select),
        .seg0_output    (seg0_output),
        .seg1_output    (seg1_output),
        .seg2_output    (seg2_output),
        .seg3_output    (seg3_output),
        .seg4_output    (seg4_output),
        .seg5_output    (seg5_output)
    );

endmodule
