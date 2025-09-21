module PixelMap(
    input wire clk,          
    input wire rst,          
    input wire start,        
    input wire donepixel,    
    input wire enable,       
    output reg donepixel,         
    output reg donemap,      
    output reg [14:0] address,
    input wire [7:0] q  
);


reg [14:0] count;            
reg [2:0] state;            
reg [7:0] reg0, reg1, reg2, reg3; 


always @(posedge donepixel or posedge rst) begin
    if (rst) begin
        count <= 15'd0;
        donemap <= 1'b0;
    end else if (enable) begin
        if (count == 15'd19200) begin
            count <= 15'd0;
            donemap <= 1'b1;
        end else begin
            count <= count + 15'd1;
            donemap <= 1'b0;
        end
    end
end


always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= 3'd0;
        donepixel <= 1'b0;
        address <= 15'd0;
        reg0 <= 8'd0;
        reg1 <= 8'd0;
        reg2 <= 8'd0;
        reg3 <= 8'd0;
    end else begin
        case (state)
            3'd0: begin
                donepixel <= 1'b0;
                if (start) begin
                    state <= 3'd1;
                end
            end
            3'd1: begin
                address <= ((count * 2) - 2) + ((count / 80) * 640);
                state <= 3'd2;
            end
            3'd2: begin
                reg0 <= q;
                address <= ((count * 2) - 1) + ((count / 80) * 640);
                state <= 3'd3;
            end
            3'd3: begin
                reg1 <= q;
                address <= (((count * 2) - 2) + 320) + ((count / 80) * 640);
                state <= 3'd4;
            end
            3'd4: begin
                reg2 <= q;
                address <= (((count * 2) - 1) + 320) + ((count / 80) * 640);
                state <= 3'd5;
            end
            3'd5: begin
                reg3 <= q;
                donepixel <= 1'b1;
                state <= 3'd0;
            end
        endcase
    end
end

endmodule
    