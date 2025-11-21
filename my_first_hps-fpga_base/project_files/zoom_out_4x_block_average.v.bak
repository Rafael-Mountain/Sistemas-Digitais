module zoom_out_4x_block_average (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input wire [7:0] rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0] ram_data,
    output reg ram_wren,
    output reg done
);
    localparam ROM_WIDTH = 160;
    localparam RAM_WIDTH = 40;
    localparam RAM_HEIGHT = 30;

    reg [5:0] state, next_state;
    localparam S_IDLE = 6'd0, S_CALC_WRITE = 6'd17, S_DONE = 6'd18;

    reg [5:0] ram_x;
    reg [4:0] ram_y;
    reg [3:0] sub_pixel_counter;

    reg [7:0] p_buf [0:15];
    reg [11:0] pixel_sum; // Soma de 16 pixels de 8 bits (16*255=4080) -> 12 bits

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    always @(posedge clk) begin
        if (reset) begin
            ram_x <= 0; ram_y <= 0; ram_wren <= 1'b0; done <= 1'b0;
            pixel_sum <= 0;
        end else begin
            ram_wren <= 1'b0;
            if (state > S_IDLE && state < S_CALC_WRITE) begin
                p_buf[state-1] <= rom_data;
            end
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0; ram_x <= 0; ram_y <= 0;
                end
                S_CALC_WRITE: begin
                    pixel_sum = p_buf[0] + p_buf[1] + p_buf[2] + p_buf[3] +
                                p_buf[4] + p_buf[5] + p_buf[6] + p_buf[7] +
                                p_buf[8] + p_buf[9] + p_buf[10] + p_buf[11] +
                                p_buf[12] + p_buf[13] + p_buf[14] + p_buf[15];
                    ram_data <= pixel_sum >> 4; // Divide por 16
                    ram_wren <= 1'b1;

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

        // Calcula o endereço do pixel no bloco 4x4 da ROM
        // state-1 atua como um contador de 0 a 15
        begin
            reg [1:0] rom_sub_y, rom_sub_x;
            rom_sub_y = (state-1) / 4;
            rom_sub_x = (state-1) % 4;
            rom_addr = ((ram_y * 4) + rom_sub_y) * ROM_WIDTH + ((ram_x * 4) + rom_sub_x);
        end
        
        case (state)
            S_IDLE: if (start) next_state = S_IDLE + 1;
            S_CALC_WRITE:
                if (ram_x == RAM_WIDTH - 1 && ram_y == RAM_HEIGHT - 1) next_state = S_DONE;
                else next_state = S_IDLE + 1;
            S_DONE: if (!start) next_state = S_IDLE;
            default: next_state = state + 1; // Avança pelos 16 estados de leitura
        endcase
    end
endmodule