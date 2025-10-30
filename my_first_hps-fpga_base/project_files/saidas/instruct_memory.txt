module instruct_memory(
    input [31:0] instruction,
    input signal,
    output reg [31:0] instruct_out
);

    always @(posedge signal) begin
        instruct_out <= instruction;
    end

endmodule
