// zoom_in_4x_replication.v
module zoom_in_4x_replication (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input  wire [7:0]  rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0]  ram_data,
    output reg        ram_wren,
    output reg        done
);
    localparam ROM_WIDTH = 160, ROM_HEIGHT = 120;
    localparam RAM_WIDTH = 640;

    localparam S_IDLE = 2'd0, S_READ_ROM = 2'd1, S_WRITE_RAM = 2'd2, S_DONE = 2'd3;
    reg [1:0] state, next_state;

    reg [7:0] rom_x;
    reg [6:0] rom_y;
    reg [3:0] write_state; // Contador para os 16 pixels a serem escritos (0 a 15)
    reg [7:0] pixel_buffer;

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_IDLE;
        else state <= next_state;
    end

    always @(posedge clk) begin
        if (reset) begin
            rom_x <= 0; rom_y <= 0; write_state <= 0;
            pixel_buffer <= 0; ram_wren <= 1'b0; done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    ram_wren <= 1'b0; done <= 1'b0;
                    rom_x <= 0; rom_y <= 0; write_state <= 0;
                end
                S_READ_ROM: begin
                    ram_wren <= 1'b0;
                    pixel_buffer <= rom_data; 
                end
                S_WRITE_RAM: begin
                    ram_wren <= 1'b1;
                    ram_data <= pixel_buffer;
                    write_state <= write_state + 1'b1;

                    if (write_state == 4'd15) begin // Terminou de escrever o bloco 4x4
                        if (rom_x == ROM_WIDTH - 1) begin
                            rom_x <= 0;
                            rom_y <= (rom_y == ROM_HEIGHT - 1) ? 0 : rom_y + 1'b1;
                        end else begin
                            rom_x <= rom_x + 1'b1;
                        end
                    end
                end
                S_DONE: begin
                    ram_wren <= 1'b0; done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        reg [1:0] sub_y, sub_x;
        next_state = state;
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        
        sub_y = write_state / 4; // Coordenada y dentro do bloco 4x4
        sub_x = write_state % 4; // Coordenada x dentro do bloco 4x4
        ram_addr = ((rom_y * 4 + sub_y) * RAM_WIDTH) + (rom_x * 4 + sub_x);

        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                if (write_state == 4'd15) begin
                    if (rom_x == ROM_WIDTH - 1 && rom_y == ROM_HEIGHT - 1) next_state = S_DONE;
                    else next_state = S_READ_ROM;
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule