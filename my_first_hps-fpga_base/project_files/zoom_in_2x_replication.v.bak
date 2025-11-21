// zoom_in_2x_replication.v
module zoom_in_2x_replication (
    input wire clk, reset, start,
    output reg [16:0] rom_addr,
    input  wire [7:0]  rom_data,
    output reg [18:0] ram_addr,
    output reg [7:0]  ram_data,
    output reg        ram_wren,
    output reg        done
);
    localparam ROM_WIDTH = 160, ROM_HEIGHT = 120;
    localparam RAM_WIDTH = 320;

    localparam S_IDLE = 2'd0, S_READ_ROM = 2'd1, S_WRITE_RAM = 2'd2, S_DONE = 2'd3;
    reg [1:0] state, next_state;

    reg [7:0] rom_x;
    reg [6:0] rom_y;
    reg [1:0] write_state; // Contador para os 4 pixels a serem escritos (0 a 3)
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

                    if (write_state == 2'b11) begin // Terminou de escrever o bloco 2x2
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
        next_state = state;
        rom_addr = (rom_y * ROM_WIDTH) + rom_x;
        
        case(write_state) // Calcula o endereço do pixel no bloco 2x2 da RAM
            2'b00: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2);
            2'b01: ram_addr = ((rom_y * 2) * RAM_WIDTH) + (rom_x * 2 + 1);
            2'b10: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2);
            default: ram_addr = ((rom_y * 2 + 1) * RAM_WIDTH) + (rom_x * 2 + 1);
        endcase

        case (state)
            S_IDLE: if (start) next_state = S_READ_ROM;
            S_READ_ROM: next_state = S_WRITE_RAM;
            S_WRITE_RAM:
                if (write_state == 2'b11) begin // Se a escrita do bloco terminou
                    if (rom_x == ROM_WIDTH - 1 && rom_y == ROM_HEIGHT - 1) next_state = S_DONE;
                    else next_state = S_READ_ROM;
                end
            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule