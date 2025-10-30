// Arquivo: processing_unit.v (COMPLETO E ATUALIZADO)

module processing_unit (
    input wire clock,
    input wire reset,
    input wire program_state,
    input wire [3:0] operation,

    input wire [7:0] pixel_in_1,
    input wire [7:0] pixel_in_2,
    input wire [7:0] pixel_in_3,
    input wire upload_reset_flag,

    input  wire [7:0]  rom_q_out_in,
    output wire [16:0] rom_addr_out,
    output wire [18:0] ram_addr_out,
    output wire [7:0]  ram_data_out,
    output wire        ram_wren_out,
    output wire processing_done
);

    localparam PROCESSING = 1'b1;
    localparam [3:0]
        OP_NONE = 4'h0, OP_REPLICATION = 4'h1, OP_DECIMATION = 4'h2,
        OP_NN = 4'h3, OP_BA = 4'h4, OP_UPLOAD = 4'h5, OP_ORIGINAL = 4'hF;

    wire start_original     = (program_state == PROCESSING) && (operation == OP_ORIGINAL);
    wire start_upload       = (program_state == PROCESSING) && (operation == OP_UPLOAD);
    wire start_replication  = (program_state == PROCESSING) && (operation == OP_REPLICATION);
    wire start_decimation   = (program_state == PROCESSING) && (operation == OP_DECIMATION);
    wire start_nn           = (program_state == PROCESSING) && (operation == OP_NN);
    wire start_ba           = (program_state == PROCESSING) && (operation == OP_BA);
    
    wire [18:0] ram_addr_upload; wire [7:0] ram_data_upload; wire ram_wren_upload; wire done_upload;
    wire [16:0] rom_addr_copy; wire [18:0] ram_addr_copy; wire [7:0] ram_data_copy; wire ram_wren_copy; wire done_copy;
    wire [16:0] rom_addr_zi1; wire [18:0] ram_addr_zi1; wire [7:0] ram_data_zi1; wire ram_wren_zi1; wire done_zi1;
    wire [16:0] rom_addr_zo1; wire [18:0] ram_addr_zo1; wire [7:0] ram_data_zo1; wire ram_wren_zo1; wire done_zo1;
    wire [16:0] rom_addr_zi2; wire [18:0] ram_addr_zi2; wire [7:0] ram_data_zi2; wire ram_wren_zi2; wire done_zi2;
    wire [16:0] rom_addr_zo2; wire [18:0] ram_addr_zo2; wire [7:0] ram_data_zo2; wire ram_wren_zo2; wire done_zo2;

    image_upload upload_inst (.clk(clock), .reset(reset), .start(start_upload), .pixel_in_1(pixel_in_1), .pixel_in_2(pixel_in_2), .pixel_in_3(pixel_in_3), .reset_addr_after_write(upload_reset_flag), .ram_addr(ram_addr_upload), .ram_data(ram_data_upload), .ram_wren(ram_wren_upload), .done(done_upload));
    original original_inst (.clk(clock), .reset(reset), .start(start_original), .rom_addr(rom_addr_copy), .rom_data(rom_q_out_in), .ram_addr(ram_addr_copy), .ram_data(ram_data_copy), .ram_wren(ram_wren_copy), .done(done_copy));
    zoom_in_replication zi_rep_inst (.clk(clock), .reset(reset), .start(start_replication), .rom_addr(rom_addr_zi1), .rom_data(rom_q_out_in), .ram_addr(ram_addr_zi1), .ram_data(ram_data_zi1), .ram_wren(ram_wren_zi1), .done(done_zi1));
    zoom_out_decimation zo_dec_inst (.clk(clock), .reset(reset), .start(start_decimation), .rom_addr(rom_addr_zo1), .rom_data(rom_q_out_in), .ram_addr(ram_addr_zo1), .ram_data(ram_data_zo1), .ram_wren(ram_wren_zo1), .done(done_zo1));
    zoom_in_nearest_neighbor zi_nn_inst (.clk(clock), .reset(reset), .start(start_nn), .rom_addr(rom_addr_zi2), .rom_data(rom_q_out_in), .ram_addr(ram_addr_zi2), .ram_data(ram_data_zi2), .ram_wren(ram_wren_zi2), .done(done_zi2));
    zoom_out_block_average zo_ba_inst (.clk(clock), .reset(reset), .start(start_ba), .rom_addr(rom_addr_zo2), .rom_data(rom_q_out_in), .ram_addr(ram_addr_zo2), .ram_data(ram_data_zo2), .ram_wren(ram_wren_zo2), .done(done_zo2));

    reg [16:0] rom_addr_out_reg;
    reg [18:0] ram_addr_out_reg;
    reg [7:0]  ram_data_out_reg;
    reg        ram_wren_out_reg;
    reg        processing_done_reg;

    always @(*) begin
        rom_addr_out_reg = 17'd0; ram_addr_out_reg = 19'd0; ram_data_out_reg = 8'd0;
        ram_wren_out_reg = 1'b0; processing_done_reg = 1'b0;

        case (operation)
            OP_ORIGINAL:    begin rom_addr_out_reg = rom_addr_copy; ram_addr_out_reg = ram_addr_copy; ram_data_out_reg = ram_data_copy; ram_wren_out_reg = ram_wren_copy; processing_done_reg = done_copy; end
            OP_UPLOAD:      begin ram_addr_out_reg = ram_addr_upload; ram_data_out_reg = ram_data_upload; ram_wren_out_reg = ram_wren_upload; processing_done_reg = done_upload; end
            OP_REPLICATION: begin rom_addr_out_reg = rom_addr_zi1; ram_addr_out_reg = ram_addr_zi1; ram_data_out_reg = ram_data_zi1; ram_wren_out_reg = ram_wren_zi1; processing_done_reg = done_zi1; end
            OP_DECIMATION:  begin rom_addr_out_reg = rom_addr_zo1; ram_addr_out_reg = ram_addr_zo1; ram_data_out_reg = ram_data_zo1; ram_wren_out_reg = ram_wren_zo1; processing_done_reg = done_zo1; end
            OP_NN:          begin rom_addr_out_reg = rom_addr_zi2; ram_addr_out_reg = ram_addr_zi2; ram_data_out_reg = ram_data_zi2; ram_wren_out_reg = ram_wren_zi2; processing_done_reg = done_zi2; end
            OP_BA:          begin rom_addr_out_reg = rom_addr_zo2; ram_addr_out_reg = ram_addr_zo2; ram_data_out_reg = ram_data_zo2; ram_wren_out_reg = ram_wren_zo2; processing_done_reg = done_zo2; end
        endcase
    end

    assign rom_addr_out = rom_addr_out_reg;
    assign ram_addr_out = ram_addr_out_reg;
    assign ram_data_out = ram_data_out_reg;
    assign ram_wren_out = ram_wren_out_reg;
    assign processing_done = processing_done_reg;
endmodule