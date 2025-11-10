// control_unit.v (FINAL - ISA v3 com Seleção Individual de Algoritmo e Limpeza de Operação)
module control_unit (
	input wire clock,
	input wire reset,
	input wire [31:0] instruction_in,
	input wire        instruction_strobe,
	input wire        processing_done,

	// SAÍDAS DE CONTROLE
	output reg         program_state,
	output reg [2:0]   operation,
	output reg [2:0]   display_mode,
	// SAÍDAS DE ALGORITMO SEPARADAS
	output reg         zoom_in_algo_select,  // 0=Replication, 1=Nearest_Neighbor
	output reg         zoom_out_algo_select  // 0=Decimation, 1=Block_Average
);

	// DEFINIÇÕES DA ISA
	wire [2:0] opcode = instruction_in[31:29];

	localparam OP_NOP            = 3'b000;
	localparam OP_ZOOM_IN        = 3'b001;
	localparam OP_ZOOM_OUT       = 3'b010;
	localparam OP_REPLICATION    = 3'b011;
	localparam OP_DECIMATION     = 3'b100;
	localparam OP_NEAREST_NEIGHBOR = 3'b101;
	localparam OP_BLOCK_AVERAGE  = 3'b110;

	// Estados e Operações
	localparam WAITING    = 1'b0;
	localparam PROCESSING = 1'b1;
	localparam ZOOM_OUT_4X = 3'b000, ZOOM_OUT_2X = 3'b001, ORIGINAL = 3'b010;
	localparam ZOOM_IN_2X  = 3'b011, ZOOM_IN_4X  = 3'b100, NONE = 3'b111;

	reg state;

	// LÓGICA SÍNCRONA (MÁQUINA DE ESTADOS)
	always @(posedge clock or posedge reset) begin
		 if (reset) begin
			  state                <= PROCESSING;
			  operation            <= ORIGINAL;
			  display_mode         <= ORIGINAL;
			  zoom_in_algo_select  <= 1'b0; // Default: Replication
			  zoom_out_algo_select <= 1'b0; // Default: Decimation
			  program_state        <= PROCESSING;
		 end else begin
			  program_state <= state;

			  case(state)
					WAITING: begin
						 if (instruction_strobe) begin
							  case (opcode)
									OP_ZOOM_IN: begin
										 if (display_mode != ZOOM_IN_4X) begin
											  state <= PROCESSING;
											  case(display_mode)
													ZOOM_OUT_4X: operation <= ZOOM_OUT_2X;
													ZOOM_OUT_2X: operation <= ORIGINAL;
													ORIGINAL:    operation <= ZOOM_IN_2X;
													default:     operation <= ZOOM_IN_4X;
											  endcase
										 end
									end
									OP_ZOOM_OUT: begin
										 if (display_mode != ZOOM_OUT_4X) begin
											  state <= PROCESSING;
											  case(display_mode)
													ZOOM_IN_4X:  operation <= ZOOM_IN_2X;
													ZOOM_IN_2X:  operation <= ORIGINAL;
													ORIGINAL:    operation <= ZOOM_OUT_2X;
													default:     operation <= ZOOM_OUT_4X;
											  endcase
										 end
									end
									OP_REPLICATION:      zoom_in_algo_select  <= 1'b0;
									OP_NEAREST_NEIGHBOR: zoom_in_algo_select  <= 1'b1;
									OP_DECIMATION:       zoom_out_algo_select <= 1'b0;
									OP_BLOCK_AVERAGE:    zoom_out_algo_select <= 1'b1;
									default: begin end
							  endcase
						 end
					end
					
					PROCESSING: begin
						 if (processing_done) begin
							  state <= WAITING;
							  if (operation != NONE) display_mode <= operation;
							  operation <= NONE; 
						 end
					end
			  endcase
		 end
	end
endmodule