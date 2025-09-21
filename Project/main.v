module main (
    input  wire clk,           
    input  wire reset_button,
    input  wire zoom_buttom,
    input  wire [1:0]type,
    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk_out,
    output wire blank
);

    

    wire nclk; 
    Clock_25MHz clk_div_inst (
        .clk(clk),
        .nclk(nclk)
    );

    wire [9:0] next_x_internal;
    wire [9:0] next_y_internal;
    reg [7:0] color_in;



    reg reset_sync;
    always @(posedge nclk) begin
        reset_sync <= ~reset_button;
    end

    wire [7:0] ram_data_out;
    wire init_done;
    reg [18:0] ram_address;
    reg [7:0] ram_data_in;
    reg ram_wren;

    Ram_access ram_access_inst (
        .clock(nclk),
        .reset(reset_sync),
        .address(ram_address),
        .data_in(ram_data_in),
        .wren_in(ram_wren),
        .q_out(ram_data_out),
        .init_done(init_done)
    );

    vga_module vga_inst (
        .clock(~nclk),
        .reset(reset_sync),
        .color_in(color_in),
        .next_x(next_x_internal),
        .next_y(next_y_internal),
        .hsync(hsync),
        .vsync(vsync),
        .red(red),
        .green(green),
        .blue(blue),
        .sync(sync),
        .clk(clk_out),
        .blank(blank)
    );
	 
    localparam OFFSET_X = 160;
    localparam OFFSET_Y = 120;

    always @(posedge nclk) begin
        if (!init_done) begin
            color_in <= 8'd0;
            ram_address <= 19'd0;
            ram_data_in <= 8'd0;
            ram_wren <= 1'b0;
        end else begin
            if ((next_x_internal >= OFFSET_X) && (next_x_internal < OFFSET_X+320) &&
                (next_y_internal >= OFFSET_Y) && (next_y_internal < OFFSET_Y+240)) begin
                ram_address <= ((next_y_internal - OFFSET_Y) * 320) + (next_x_internal - OFFSET_X);
                color_in <= ram_data_out;
            end else begin
                ram_address <= 19'd0; 
                color_in <= 8'd0;     
            end

            ram_data_in <= 8'd0;
            ram_wren    <= 1'b0;
        end
    end

endmodule
