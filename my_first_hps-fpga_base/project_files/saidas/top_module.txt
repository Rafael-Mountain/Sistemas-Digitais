// top_module.v
module top_module (
    input [31:0] hps_pio_data,      // Entrada de 32 bits vinda do PIO
    input        display_select,    // Sinal de seleção (de SW[0])

    // Saídas para os displays de 7 segmentos
    output [6:0] seg0_output, // HEX0 (Dígito 0 ou 4)
    output [6:0] seg1_output, // HEX1 (Dígito 1 ou 5)
    output [6:0] seg2_output, // HEX2 (Dígito 2 ou 6)
    output [6:0] seg3_output, // HEX3 (Dígito 3 ou 7)
    output [6:0] seg4_output, // HEX4 (Desligado)
    output [6:0] seg5_output  // HEX5 (Indicador High/Low)
);

    // Sinais internos para todos os 8 dígitos hexadecimais
    wire [3:0] hex_d0, hex_d1, hex_d2, hex_d3, hex_d4, hex_d5, hex_d6, hex_d7;

    // Sinais para os 4 dígitos que serão enviados aos drivers
    reg [3:0] selected_d0, selected_d1, selected_d2, selected_d3;

    // Instanciar o módulo de conversão de 32 bits
    bin_to_hex u_bin_to_hex (
        .bin_input   (hps_pio_data),
        .hex_digit0  (hex_d0), .hex_digit1  (hex_d1),
        .hex_digit2  (hex_d2), .hex_digit3  (hex_d3),
        .hex_digit4  (hex_d4), .hex_digit5  (hex_d5),
        .hex_digit6  (hex_d6), .hex_digit7  (hex_d7)
    );

    // Lógica para multiplexar qual parte do número será exibida
    always @* begin
        if (display_select) begin // Se SW[0] = 1, mostrar parte ALTA
            selected_d0 = hex_d4;
            selected_d1 = hex_d5;
            selected_d2 = hex_d6;
            selected_d3 = hex_d7;
        end else begin // Se SW[0] = 0, mostrar parte BAIXA
            selected_d0 = hex_d0;
            selected_d1 = hex_d1;
            selected_d2 = hex_d2;
            selected_d3 = hex_d3;
        end
    end

    // Instanciar os 4 drivers de display
    hex_seven_segment_driver u_driver0 ( .hex_input(selected_d0), .segment_output(seg0_output) );
    hex_seven_segment_driver u_driver1 ( .hex_input(selected_d1), .segment_output(seg1_output) );
    hex_seven_segment_driver u_driver2 ( .hex_input(selected_d2), .segment_output(seg2_output) );
    hex_seven_segment_driver u_driver3 ( .hex_input(selected_d3), .segment_output(seg3_output) );

    // Desliga o display HEX4
    assign seg4_output = 7'b1111111;

    // Usa o display HEX5 como um indicador:
    // Mostra um 'H' (High) se a parte alta estiver selecionada, ou 'L' (Low) se a parte baixa.
    assign seg5_output = (display_select) ? 7'b0001001 : 7'b1000111; // H : L

endmodule