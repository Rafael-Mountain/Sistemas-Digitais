// bin_to_hex.v
module bin_to_hex (
    input [31:0] bin_input,
    output [3:0] hex_digit0, // LSB
    output [3:0] hex_digit1,
    output [3:0] hex_digit2,
    output [3:0] hex_digit3,
    output [3:0] hex_digit4,
    output [3:0] hex_digit5,
    output [3:0] hex_digit6,
    output [3:0] hex_digit7  // MSB
);

    // Divide a entrada de 32 bits em 8 nibbles de 4 bits
    assign hex_digit0 = bin_input[3:0];
    assign hex_digit1 = bin_input[7:4];
    assign hex_digit2 = bin_input[11:8];
    assign hex_digit3 = bin_input[15:12];
    assign hex_digit4 = bin_input[19:16];
    assign hex_digit5 = bin_input[23:20];
    assign hex_digit6 = bin_input[27:24];
    assign hex_digit7 = bin_input[31:28];

endmodule