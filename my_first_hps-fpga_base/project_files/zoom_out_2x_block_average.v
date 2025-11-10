// zoom_out_2x_block_average.v
module zoom_out_2x_block_average (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input wire [7:0] rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0] ram_data,
    output reg ram_wren,
    output reg done
);
    localparam ROM_WIDTH = 160;
    localparam RAM_WIDTH = 80, RAM_HEIGHT = 60;

    localparam S_IDLE=0, S_READ_00=1, S_READ_01=2, S_READ_10=3, S_READ_11=4, S_CALC_WRITE=5, S_DONE=6;
    reg [2:0] state, next_state;

    reg [6:0] ram_x;
    reg [5:0] ram_y;
    reg [7:0] p00, p01, p10, p11;
    reg [9:0] pixel_sum;

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0;
            p00 <= 0; p01 <= 0; p10 <= 0; p11 <= 0;
        end else begin
            ram_wren <= 1'b0;
            case (state)
                S_IDLE: begin done <= 1'b0; ram_x <= 0; ram_y <= 0; end
                S_READ_00: p00 <= rom_data;
                S_READ_01: p01 <= rom_data;
                S_READ_10: p10 <= rom_data;
                S_READ_11: p11 <= rom_data;
                S_CALC_WRITE: begin
                    ram_wren <= 1'b1;
                    pixel_sum = p00 + p01 + p10 + p11;
                    ram_data <= pixel_sum >> 2;

                    if (ram_x == RAM_WIDTH - 1) begin
                        ram_x <= 0;
                        ram_y <= (ram_y == RAM_HEIGHT - 1) ? 0 : ram_y + 1;
                    end else begin
                        ram_x <= ram_x + 1;
                    end
                end
                S_DONE: done <= 1'b1;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;

        case(state)
            S_READ_00: rom_addr = ((ram_y*2)+0)*ROM_WIDTH + ((ram_x*2)+0);
            S_READ_01: rom_addr = ((ram_y*2)+0)*ROM_WIDTH + ((ram_x*2)+1);
            S_READ_10: rom_addr = ((ram_y*2)+1)*ROM_WIDTH + ((ram_x*2)+0);
            S_READ_11: rom_addr = ((ram_y*2)+1)*ROM_WIDTH + ((ram_x*2)+1);
            default:   rom_addr = 17'd0;
        endcase

        case (state)
            S_IDLE:       if(start) next_state = S_READ_00;
            S_READ_00:    next_state = S_READ_01;
            S_READ_01:    next_state = S_READ_10;
            S_READ_10:    next_state = S_READ_11;
            S_READ_11:    next_state = S_CALC_WRITE;
            S_CALC_WRITE:
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1) next_state = S_DONE;
                else next_state = S_READ_00;
            S_DONE:       if (!start) next_state = S_IDLE;
        endcase
    end
endmodule