// Arquivo: control_unit.v (COMPLETO E ATUALIZADO)

module control_unit (
	input wire clock,
	input wire reset,
	input wire processing_done,
	
    input wire [31:0] instruct,
	input wire begin_f,
        
    output reg done_instruction,

	output wire program_state,
	output reg [3:0] operation,
	output reg [1:0] display_mode,
    
    output reg [7:0] pixel_out_1,
    output reg [7:0] pixel_out_2,
    output reg [7:0] pixel_out_3,
    output reg upload_reset_out
);

	localparam WAITING    = 1'b0;
	localparam PROCESSING = 1'b1;
	
	localparam D_ORIGINAL = 2'b00, D_ZOOM_OUT = 2'b01, D_ZOOM_IN  = 2'b10;
	
    localparam [3:0]
        OP_NONE            = 4'h0, OP_REPLICATION     = 4'h1,
        OP_DECIMATION      = 4'h2, OP_NN              = 4'h3,
        OP_BA              = 4'h4, OP_UPLOAD          = 4'h5,
        OP_ORIGINAL        = 4'hF;

	reg state, next_state;
	assign program_state = state;
	
	wire [2:0] opcode;
    wire [7:0] pixel1_in, pixel2_in, pixel3_in;
    wire       upload_reset_in;

    instruct_decoder decoder_inst (
        .instr(instruct), .state(opcode), .pixel1(pixel1_in),
        .pixel2(pixel2_in), .pixel3(pixel3_in), .upload_reset_flag(upload_reset_in)
    );
	
	always @(posedge clock or posedge reset) begin
		if (reset) begin
			state <= WAITING; operation <= OP_ORIGINAL; display_mode <= D_ORIGINAL;
            done_instruction <= 1'b0; upload_reset_out <= 1'b0;
            pixel_out_1 <= 0; pixel_out_2 <= 0; pixel_out_3 <= 0;
		end else begin
			state <= next_state;
			
            if (state == PROCESSING && next_state == WAITING) done_instruction <= 1'b1;
            else done_instruction <= 1'b0;

			if (state == WAITING && next_state == PROCESSING) begin
				case(opcode)
                    3'b000:  operation <= OP_REPLICATION;
                    3'b001:  operation <= OP_DECIMATION;
                    3'b010:  operation <= OP_NN;
                    3'b011:  operation <= OP_BA;
                    3'b100:  begin
                        operation <= OP_UPLOAD; pixel_out_1 <= pixel1_in;
                        pixel_out_2 <= pixel2_in; pixel_out_3 <= pixel3_in;
                        upload_reset_out <= upload_reset_in;
                    end
                    default: begin
                        operation <= OP_NONE; upload_reset_out <= 1'b0;
                    end
                endcase
			end else begin
                upload_reset_out <= 1'b0;
            end
			
			if (state == PROCESSING && processing_done) begin
				case(operation)
					OP_REPLICATION, OP_NN: display_mode <= D_ZOOM_IN;
					OP_DECIMATION, OP_BA:  display_mode <= D_ZOOM_OUT;
					default:               display_mode <= display_mode;
				endcase
			end
		end
	end

	always @(*) begin
		next_state = state;
		case(state)
			WAITING:    if (begin_f) next_state = PROCESSING;
			PROCESSING: if (processing_done) next_state = WAITING;
		endcase
	end

endmodule