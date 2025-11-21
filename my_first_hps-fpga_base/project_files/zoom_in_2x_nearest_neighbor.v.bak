// zoom_in_2x_nearest_neighbor.v
module zoom_in_2x_nearest_neighbor (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input  wire [7:0]  rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0]  ram_data,
    output reg        ram_wren,
    output reg        done
);
    localparam ROM_WIDTH  = 160;
    localparam RAM_WIDTH  = 320;
    localparam RAM_HEIGHT = 240;

    localparam S_IDLE=2'd0, S_READ_ROM=2'd1, S_WRITE_RAM=2'd2, S_DONE=2'd3;
    reg [1:0] state, next_state;

    reg [8:0] ram_x;
    reg [7:0] ram_y;
    reg [7:0] pixel_buffer;

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0; pixel_buffer <= 0;
        end else begin
            case (state)
                S_IDLE: begin done <= 1'b0; ram_wren <= 1'b0; ram_x <= 0; ram_y <= 0; end
                S_READ_ROM: begin ram_wren <= 1'b0; pixel_buffer <= rom_data; end
                S_WRITE_RAM: begin
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer;
                    if (ram_x == RAM_WIDTH - 1) begin
                        ram_x <= 0;
                        ram_y <= (ram_y == RAM_HEIGHT - 1) ? 0 : ram_y + 1;
                    end else begin
                        ram_x <= ram_x + 1;
                    end
                end
                S_DONE: begin ram_wren <= 1'b0; done <= 1'b1; end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        rom_addr = ((ram_y >> 1) * ROM_WIDTH) + (ram_x >> 1);
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1) next_state = S_DONE;
                else next_state = S_READ_ROM;
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule