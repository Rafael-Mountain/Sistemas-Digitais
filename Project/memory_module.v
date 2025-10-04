// Arquivo: memory_module.v (VERSÃO CORRIGIDA E PASSIVA)
// Descrição: Este módulo agora é um simples invólucro para a RAM e a ROM.
// Ele não contém lógica de controle; apenas conecta as portas conforme
// comandado pelo módulo 'main'.

module memory_module(
    input  wire        clock,
    input  wire        reset,

    // --- Interface externa RAM ---
    input  wire [18:0] ram_address,      // Endereço final vindo do árbitro em 'main'
    input  wire [7:0]  ram_data_in,      // Dado para escrita vindo do árbitro
    input  wire        wren_in,          // Write enable vindo do árbitro
    output wire [7:0]  q_out_ram,        // Dado lido da RAM

    // --- Interface externa ROM ---
    input  wire [16:0] rom_address_ext,  // Endereço vindo do árbitro em 'main'
    output wire [7:0]  q_out_rom,        // Dado lido da ROM

    output wire        done
);

    // Conecta diretamente a saída 'done' a um valor fixo, pois a lógica de 'done'
    // agora está nos módulos de processamento individuais.
    assign done = 1'b0;

    // --- Instância da ROM ---
    // A ROM é controlada diretamente pelas entradas do módulo.
    rom inst_rom (
        .address (rom_address_ext),
        .clock   (clock),
        .q       (q_out_rom)
    );

    // --- Instância da RAM ---
    // A RAM é controlada diretamente pelas entradas do módulo.
    ram inst_ram (
        .address (ram_address),
        .clock   (clock),
        .data    (ram_data_in),
        .wren    (wren_in),
        .q       (q_out_ram)
    );

endmodule
