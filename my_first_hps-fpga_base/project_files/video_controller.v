// ================================================================================
// Módulo: video_controller.v
//
// Descrição:
// Este é o controlador de vídeo de alto nível. Sua principal função não é gerar
// os sinais de temporização VGA brutos (essa tarefa é delegada ao `vga_module`),
// mas sim gerenciar o conteúdo que será exibido na tela.
//
// Funcionalidades Principais:
// 1. Recebe as coordenadas do pixel atual (`vga_x`, `vga_y`) do `vga_module`.
// 2. Com base no `display_mode` (que informa a resolução da imagem a ser
//    exibida), calcula as dimensões e os offsets necessários para centralizar
//    a imagem na tela de 640x480.
// 3. Se as coordenadas do pixel atual estiverem dentro da área da imagem
//    centralizada, ele calcula o endereço correspondente na `ram_op` e o
//    envia para a memória.
// 4. Implementa um pipeline de leitura de 1 ciclo para lidar com a latência da
//    RAM. As decisões sobre o que mostrar na tela são atrasadas em um ciclo de
//    clock para se alinharem com os dados que chegam da RAM.
// 5. Se o sinal `processing_active` estiver ativo, ele exibe uma cor de fundo
//    sólida para evitar que o usuário veja "lixo" na tela enquanto a
//    `processing_unit` está escrevendo na `ram_op`.
// 6. Envia a cor final do pixel (seja da imagem ou do fundo) para o `vga_module`.
// ================================================================================

module video_controller (
    // --- Entradas ---
    input  wire         clk,                // Clock do sistema (25MHz).
    input  wire         reset,              // Sinal de reset síncrono.
    input  wire [2:0]   display_mode,     // Código que define a resolução da imagem a ser exibida.
    input  wire [7:0]   ram_data_in,      // Dado de pixel de 8 bits vindo da `ram_op`.
    input  wire         processing_active,  // Indica se a `processing_unit` está escrevendo na RAM.

    // --- Saídas ---
    output reg  [18:0]  ram_addr_out,       // Endereço enviado para a `ram_op` para leitura.
    output wire         hsync, vsync,       // Sinais de sincronismo VGA.
    output wire [7:0]   red, green, blue,   // Dados de cor para o DAC do VGA.
    output wire         sync, clk_out, blank // Outros sinais de controle VGA.
);

    // Cor de fundo exibida quando fora da área da imagem ou durante o processamento.
    parameter [7:0] BACKGROUND_COLOR = 8'h24; // Um tom de azul.
    
    // Constantes para os modos de exibição (para legibilidade).
	localparam D_ZOOM_OUT_4X = 3'b000; // 40x30
	localparam D_ZOOM_OUT_2X = 3'b001; // 80x60
	localparam D_ORIGINAL    = 3'b010; // 160x120
	localparam D_ZOOM_IN_2X  = 3'b011; // 320x240
	localparam D_ZOOM_IN_4X  = 3'b100; // 640x480

    // --- Sinais Internos ---
    wire [9:0] vga_x, vga_y;        // Coordenadas do pixel atual, vindas do `vga_module`.
    wire [7:0] final_pixel_color;    // Cor final a ser enviada para o `vga_module`.
    wire       is_in_image_area_comb; // Lógica combinacional que verifica se (vga_x, vga_y) está na área da imagem.

    // --- Lógica de Centralização da Imagem ---
    // Determina a largura e altura da imagem a ser exibida com base no `display_mode`.
    reg [9:0] current_img_width, current_img_height;
    always @(*) begin 
        case(display_mode)
            D_ZOOM_IN_4X:  begin current_img_width = 10'd640; current_img_height = 10'd480; end
            D_ZOOM_IN_2X:  begin current_img_width = 10'd320; current_img_height = 10'd240; end
            D_ZOOM_OUT_2X: begin current_img_width = 10'd80;  current_img_height = 10'd60;  end
            D_ZOOM_OUT_4X: begin current_img_width = 10'd40;  current_img_height = 10'd30;  end
            default:       begin current_img_width = 10'd160; current_img_height = 10'd120; end // D_ORIGINAL
        endcase
    end
    
    // Calcula o deslocamento (offset) necessário para centralizar a imagem na tela de 640x480.
    wire [9:0] offset_x = (640 - current_img_width) >> 1; // Divisão por 2
    wire [9:0] offset_y = (480 - current_img_height) >> 1; // Divisão por 2

    // --- PIPELINE DE LEITURA E ESTADO ---
    // As memórias RAM têm uma latência de leitura de 1 ciclo. Isso significa que,
    // quando um endereço é enviado em um ciclo de clock, o dado correspondente
    // só está disponível na saída da RAM no ciclo seguinte. Para garantir que
    // as decisões (como "estou dentro da imagem?") estejam sincronizadas com
    // os dados que chegam, os sinais de controle também precisam ser atrasados
    // em 1 ciclo.
    
    // Registradores para atrasar os sinais de controle em 1 ciclo.
    reg is_in_image_area_d1;  // Versão registrada (atrasada) de `is_in_image_area_comb`.
    reg processing_active_d1; // Versão registrada (atrasada) de `processing_active`.

    always @(posedge clk) begin
        if (reset) begin
            ram_addr_out <= 19'd0;
            is_in_image_area_d1 <= 1'b0;
            processing_active_d1 <= 1'b1; // Começa com a tela "apagada" por segurança.
        end else begin
            // --- Ciclo 1: Cálculo e Envio do Endereço ---
            // Neste ciclo, calculamos o endereço para o *próximo* pixel e o enviamos para a RAM.
            // Ao mesmo tempo, capturamos o estado atual dos sinais de controle nos registradores de pipeline.
            
            // Registra os sinais de controle para uso no próximo ciclo.
            processing_active_d1 <= processing_active;
            is_in_image_area_d1 <= is_in_image_area_comb;
            
            // Calcula o endereço para o pixel (vga_x, vga_y) que será desenhado a seguir.
            if (is_in_image_area_comb) begin
                ram_addr_out <= ((vga_y - offset_y) * current_img_width) + (vga_x - offset_x);
            end else begin
                ram_addr_out <= 19'd0; // Endereço padrão se estiver fora da imagem.
            end
        end
    end
    
    // Lógica combinacional para verificar se as coordenadas do *próximo* pixel a ser desenhado
    // (`vga_x`, `vga_y`) estão dentro da área da imagem centralizada.
    assign is_in_image_area_comb = (vga_x >= offset_x) && (vga_x < offset_x + current_img_width) &&
                                   (vga_y >= offset_y) && (vga_y < offset_y + current_img_height);
                                  
    // --- Ciclo 2: Decisão e Saída da Cor ---
    // Neste ciclo, o dado (`ram_data_in`) do endereço enviado no ciclo anterior chega.
    // Usamos os sinais de controle registrados (`_d1`) para tomar a decisão final sobre
    // qual cor enviar ao `vga_module`, garantindo perfeita sincronia.
    assign final_pixel_color = processing_active_d1 ? BACKGROUND_COLOR : 
                               (is_in_image_area_d1 ? ram_data_in : BACKGROUND_COLOR);

    // --- Instância do Módulo VGA de Baixo Nível ---
    // Este módulo gera toda a temporização (HSYNC, VSYNC) e fornece as
    // coordenadas (x,y) do pixel que precisa ser desenhado.
    vga_module vga_inst (
        .clock(clk),
        .reset(reset), 
        .color_in(final_pixel_color), // Envia a cor do pixel que calculamos.
        .next_x(vga_x),               // Recebe a coordenada x do próximo pixel.
        .next_y(vga_y),               // Recebe a coordenada y do próximo pixel.
        .hsync(hsync), .vsync(vsync),
        .red(red), .green(green), .blue(blue), .sync(sync),
        .clk(clk_out), .blank(blank)
    );

endmodule