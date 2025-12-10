module clock_divider (
	input wire clock_in,
	output reg clock_out
);

	always @(posedge clock_in) begin
		clock_out <= ~clock_out;
	end

endmodule