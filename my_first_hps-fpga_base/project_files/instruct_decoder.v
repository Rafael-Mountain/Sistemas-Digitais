// Arquivo: instruct_decoder.v (COMPLETO E ATUALIZADO)

module instruct_decoder (
    input  wire [31:0] instr,
    output reg  [2:0]  state,
    output reg  [7:0]  pixel1,
    output reg  [7:0]  pixel2,
    output reg  [7:0]  pixel3,
    output reg         upload_reset_flag
);

    localparam [2:0]
        REPLICATION      = 3'b000, DECIMATION       = 3'b001,
        NEAREST_NEIGHBOR = 3'b010, BLOCK_AVERAGE    = 3'b011,
        IMAGE_UPLOAD     = 3'b100;

    always @(*) begin
        state = instr[31:29];
        pixel1 = 8'd0; pixel2 = 8'd0; pixel3 = 8'd0;
        upload_reset_flag = 1'b0;

        case (state)
            IMAGE_UPLOAD: begin
                pixel1 = instr[28:21];
                pixel2 = instr[20:13];
                pixel3 = instr[12:5];
                upload_reset_flag = instr[0]; 
            end
            REPLICATION, DECIMATION, NEAREST_NEIGHBOR, BLOCK_AVERAGE: begin
                // Sem pixels, apenas comando
            end
            default: begin
                // Instrução inválida
            end
        endcase
    end
endmodule