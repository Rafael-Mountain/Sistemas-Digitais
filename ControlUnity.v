module ControlUnity(
	input [1:0]InstructionType,
	input [31:0]data,
	input contadorSignal,
	input imageWidth,
	input imageHigth,
	output write
);



wire []alu_in;
	
reg [7:0] Nquadrante;
always @(posedge contadorSignal) begin
    Nquadrante <= Nquadrante + 1'b1;
end

reg [7:0] npixel;
always @() begin
    npixel <= npixel + 1'b1;
end


	always @(*)begin 
		if (InstructionType == 2'b11) begin
            alu_in = data;
        end else begin
            case(counter)
						
                default: alu_in = 32'd0;
           endcase
       end
	end
	
	always @(*)begin
		if (InstructionType == 2'b11)
			
	
	
endmodule