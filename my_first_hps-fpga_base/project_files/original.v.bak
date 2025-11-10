// Arquivo: original.v
// Descrição: Copia a imagem original de 320x240 da ROM para a RAM.

module original (
    input wire clk,
    input wire reset,
    input wire start,

    // Interface com a ROM (Leitura)
    output reg  [16:0] rom_addr,
    input  wire [7:0]  rom_data,

    // Interface com a RAM (Escrita)
    output reg  [18:0] ram_addr,
    output reg  [7:0]  ram_data,
    output reg         ram_wren,

    output reg         done
);

    localparam IMAGE_SIZE = 76800; // 320 * 240
    localparam RAM_SIZE_TO_CLEAR = 307200; // 640 * 480 (para limpar toda a RAM)

    reg [18:0] addr_counter;
    reg processing;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            addr_counter <= 0;
            ram_wren <= 1'b0;
            done <= 1'b0;
            processing <= 1'b0;
        end else begin
            if (start && !processing) begin
                // Inicia o processo
                processing <= 1'b1;
                addr_counter <= 0;
                done <= 1'b0;
            end else if (processing) begin
                ram_wren <= 1'b1; // Mantém a escrita ativa durante o processo
                
                if (addr_counter == RAM_SIZE_TO_CLEAR - 1) begin
                    // Terminou
                    processing <= 1'b0;
                    done <= 1'b1;
                    ram_wren <= 1'b0;
                end else begin
                    addr_counter <= addr_counter + 1;
                end
            end else begin
                 // Estado ocioso
                 ram_wren <= 1'b0;
                 done <= 1'b0;
            end
        end
    end

    // Lógica combinacional para os endereços e dados
    always @(*) begin
        // Endereço é o mesmo para ROM e RAM durante a cópia
        rom_addr = addr_counter[16:0];
        ram_addr = addr_counter;

        // Se estivermos na área da imagem, copia o dado da ROM.
        // Se não, escreve zero para limpar o resto da RAM.
        if (addr_counter < IMAGE_SIZE) begin
            ram_data = rom_data;
        end else begin
            ram_data = 8'd0;
        end
    end

endmodule