module seven_segment_driver (
    input [2:0] octal_input, // Entrada de 3 bits para o dígito octal
    output reg [6:0] segment_output // Saída de 7 bits para os segmentos (a-g)
);

    // Mapeamento comum para displays de 7 segmentos (anodo comum)
    // Para catodo comum, inverta os bits.
    //    --a--
    //   |     |
    //   f     b
    //   |     |
    //    --g--
    //   |     |
    //   e     c
    //   |     |
    //    --d--
    // Segmentos: gfedcba

    always @* begin
        case (octal_input)
            3'b000: segment_output = 7'b1000000; // 0
            3'b001: segment_output = 7'b1111001; // 1
            3'b010: segment_output = 7'b0100100; // 2
            3'b011: segment_output = 7'b0110000; // 3
            3'b100: segment_output = 7'b0011001; // 4
            3'b101: segment_output = 7'b0010010; // 5
            3'b110: segment_output = 7'b0000010; // 6
            3'b111: segment_output = 7'b1111000; // 7
            default: segment_output = 7'b1111111; // Apagar ou erro
        endcase
    end

endmodule