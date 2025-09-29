module memory_module(
    input  wire        clock,
    input  wire        reset,            // inicia cópia ROM -> RAM

    // --- Interface externa RAM ---
    input  wire [18:0] ram_address,      // endereço externo RAM
    input  wire [7:0]  ram_data_in,      // dado externo p/ escrita
    input  wire        wren_in,          // habilita escrita externa
    output wire [7:0]  q_out_ram,        // dado lido da RAM

    // --- Interface externa ROM ---
    input  wire [16:0] rom_address_ext,  // endereço externo ROM
    output wire [7:0]  q_out_rom,        // dado lido da ROM

    output reg         done              // indica que a cópia terminou
);

    // --- Constantes ---
    localparam ROM_SIZE = 17'd76800;     // palavras da ROM
    localparam RAM_SIZE = 19'd307200;    // palavras da RAM

    // --- Sinais internos ---
    reg  [18:0] copy_addr;    // endereço interno de cópia (ROM + zerar resto)
    wire [7:0]  rom_data;     // dado vindo da ROM

    reg  [18:0] ram_addr;
    reg  [7:0]  ram_data;
    reg         ram_wren;
    wire [7:0]  ram_q;

    reg copying;  // indica se ainda estamos copiando

    // --- Instância da ROM ---
    Rom inst_rom (
        .address(copying && (copy_addr < ROM_SIZE) ? copy_addr[16:0] : rom_address_ext),
        .clock(clock),
        .q(rom_data)
    );

    assign q_out_rom = rom_data; // saída externa da ROM

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
            copy_addr <= 19'd0;
            ram_addr  <= 19'd0;
            ram_data  <= 8'd0;
            ram_wren  <= 1'b0;
            copying   <= 1'b1;
            done      <= 1'b0;
        end else if (copying) begin
            // Escrita na RAM durante cópia
            ram_addr <= copy_addr;

            if (copy_addr < ROM_SIZE) begin
                // Fase 1: copia ROM
                ram_data <= rom_data;
                ram_wren <= 1'b1;
            end else if (copy_addr < RAM_SIZE) begin
                // Fase 2: preenche resto com zeros
                ram_data <= 8'd0;
                ram_wren <= 1'b1;
            end

            // Avança
            if (copy_addr == (RAM_SIZE-1)) begin
                copying   <= 1'b0;
                done      <= 1'b1;
                ram_wren  <= 1'b0;
            end else begin
                copy_addr <= copy_addr + 1'b1;
            end
        end else begin
            // Modo normal: acesso externo RAM
            ram_addr <= ram_address;
            ram_data <= ram_data_in;
            ram_wren <= wren_in;
        end
    end

    // Saída da RAM
    assign q_out_ram = ram_q;

endmodule
