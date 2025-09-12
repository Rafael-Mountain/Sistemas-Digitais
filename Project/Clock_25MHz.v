module Clock_25MHz (
    input clk,       
    output reg nclk   
);

always @(posedge clk) begin
	nclk <= ~nclk;
end

endmodule