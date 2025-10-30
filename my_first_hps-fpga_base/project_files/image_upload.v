// Arquivo: image_upload.v (NOVO ARQUIVO)

module image_upload (
    input wire clk,
    input wire reset,
    input wire start,

    input wire [7:0] pixel_in_1,
    input wire [7:0] pixel_in_2,
    input wire [7:0] pixel_in_3,
    input wire reset_addr_after_write,

    output reg  [18:0] ram_addr,
    output reg  [7:0]  ram_data,
    output reg         ram_wren,
    output reg         done
);

    localparam S_IDLE = 3'd0, S_WRITE_1 = 3'd1, S_WRITE_2 = 3'd2, S_WRITE_3 = 3'd3, S_DONE = 3'd4;
    reg [2:0] state, next_state;
    reg [18:0] current_ram_addr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            current_ram_addr <= 19'd0;
        end else begin
            state <= next_state;
            if (state == S_WRITE_3) begin
                if (reset_addr_after_write) current_ram_addr <= 19'd0;
                else current_ram_addr <= current_ram_addr + 3;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin ram_wren <= 1'b0; done <= 1'b0; end
        else begin
            ram_wren <= (state == S_WRITE_1 || state == S_WRITE_2 || state == S_WRITE_3);
            done <= (state == S_DONE);
        end
    end
    
    always @(*) begin
        next_state = state; ram_addr = current_ram_addr; ram_data = 8'd0;
        case(state)
            S_IDLE:    if (start) next_state = S_WRITE_1;
            S_WRITE_1: begin ram_addr = current_ram_addr;     ram_data = pixel_in_1; next_state = S_WRITE_2; end
            S_WRITE_2: begin ram_addr = current_ram_addr + 1; ram_data = pixel_in_2; next_state = S_WRITE_3; end
            S_WRITE_3: begin ram_addr = current_ram_addr + 2; ram_data = pixel_in_3; next_state = S_DONE; end
            S_DONE:    if (!start) next_state = S_IDLE;
        endcase
    end
endmodule