// hex_seven_segment_driver.v
module hex_seven_segment_driver (
    input [3:0] hex_input,      // Entrada de 4 bits para o dígito hexadecimal
    output reg [6:0] segment_output // Saída de 7 bits para os segmentos (a-g)
);
    // Mapeamento para display de 7 segmentos (anodo comum, ativo em nível baixo)
    // Segmentos: gfedcba
    always @* begin
        case (hex_input)
            4'h0: segment_output = 7'b1000000; // 0
            4'h1: segment_output = 7'b1111001; // 1
            4'h2: segment_output = 7'b0100100; // 2
            4'h3: segment_output = 7'b0110000; // 3
            4'h4: segment_output = 7'b0011001; // 4
            4'h5: segment_output = 7'b0010010; // 5
            4'h6: segment_output = 7'b0000010; // 6
            4'h7: segment_output = 7'b1111000; // 7
            4'h8: segment_output = 7'b0000000; // 8
            4'h9: segment_output = 7'b0010000; // 9
            4'hA: segment_output = 7'b0001000; // A
            4'hB: segment_output = 7'b0000011; // b (minúsculo para diferenciar do 8)
            4'hC: segment_output = 7'b1000110; // C
            4'hD: segment_output = 7'b0100001; // d (minúsculo para diferenciar do 0)
            4'hE: segment_output = 7'b0000110; // E
            4'hF: segment_output = 7'b0001110; // F
            default: segment_output = 7'b1111111; // Desligado
        endcase
    end

endmodule