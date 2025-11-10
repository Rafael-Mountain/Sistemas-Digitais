module sync_reset_button (
	input wire clock,
	input wire reset_button_in,
	output reg reset_sync_out
);

	always @(posedge clock) begin
		reset_sync_out <= ~reset_button_in;
	end

endmodule