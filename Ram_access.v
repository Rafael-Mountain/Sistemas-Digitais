module Ram_access(
    input  wire        clock,
    input  wire        reset,        // inicia cópia ROM -> RAM
    input  wire [18:0] address,      // endereço externo para RAM
    input  wire [7:0]  data_in,      // dado externo para escrita
    input  wire        wren_in,      // habilita escrita externa
    output wire [7:0]  q_out,        // dado lido da RAM
    output reg         init_done     // indica que a cópia terminou
);

    // --- Sinais internos ---
    reg [16:0] rom_addr;      // endereço de leitura da ROM (0..76799)
    wire [7:0] rom_data;      // dados vindos da ROM

    reg [18:0] ram_addr;
    reg [7:0]  ram_data;
    reg        ram_wren;
    wire [7:0] ram_q;

    reg copying;  // indica se ainda estamos copiando

    // --- Instância da ROM ---
    Rom inst_rom (
        .address(rom_addr),
        .clock(clock),
        .q(rom_data)
    );

    // --- Instância da RAM ---
    Ram inst_ram (
        .address(ram_addr),
        .clock(clock),
        .data(ram_data),
        .wren(ram_wren),
        .q(ram_q)
    );

    // --- Controle da cópia ROM -> RAM ---
    always @(posedge clock) begin
        if (reset) begin
            rom_addr   <= 17'd0;
            ram_addr   <= 19'd0;
            ram_data   <= 8'd0;
            ram_wren   <= 1'b0;
            copying    <= 1'b1;
            init_done  <= 1'b0;
        end else if (copying) begin
            // copia ROM para RAM (endereços 0..76799)
            ram_addr <= rom_addr;  // RAM recebe na mesma posição da ROM
            ram_data <= rom_data;
            ram_wren <= 1'b1;

            // avança endereço ROM
            if (rom_addr == 17'd76799) begin
                copying   <= 1'b0;
                init_done <= 1'b1;
                ram_wren  <= 1'b0;
            end else begin
                rom_addr <= rom_addr + 1'b1;
            end
        end else begin
            // modo normal -> interface externa controla RAM
            ram_addr <= address;
            ram_data <= data_in;
            ram_wren <= wren_in;
        end
    end

    // Saída da RAM
    assign q_out = ram_q;

endmodule
