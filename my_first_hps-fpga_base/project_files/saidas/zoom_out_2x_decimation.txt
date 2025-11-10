// zoom_out_2x_decimation.v
module zoom_out_2x_decimation (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input  wire [7:0]  rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0]  ram_data,
    output reg        ram_wren,
    output reg        done
);
    localparam ROM_WIDTH = 160, ROM_HEIGHT = 120;
    localparam RAM_WIDTH = 80;

    localparam S_IDLE = 2'd0, S_PROCESS = 2'd1, S_DONE = 2'd2;
    reg [1:0] state, next_state;

    reg [7:0] ram_x;
    reg [6:0] ram_y;
    reg pixel_valid; // Flag para pipeline de 1 ciclo de leitura

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end
    
    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0;
            pixel_valid <= 1'b0; done <= 1'b0;
        end else begin
            ram_wren <= 1'b0;
            pixel_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_PROCESS: begin
                    if (pixel_valid) begin
                        ram_wren <= 1'b1;
                        ram_data <= rom_data;
                        
                        if (ram_x == RAM_WIDTH - 1) begin
                            ram_x <= 0;
                            ram_y <= ram_y + 1;
                        end else begin
                            ram_x <= ram_x + 1;
                        end
                    end
                    pixel_valid <= 1'b1; 
                end
                S_DONE: done <= 1'b1;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        rom_addr = ((ram_y * 2) * ROM_WIDTH) + (ram_x * 2);
        ram_addr = (ram_y * RAM_WIDTH) + ram_x;
        
        case (state)
            S_IDLE: if (start) next_state = S_PROCESS;
            S_PROCESS:
                if (pixel_valid && ram_x == RAM_WIDTH - 1 && ram_y == ROM_HEIGHT/2 - 1) begin
                    next_state = S_DONE;
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule