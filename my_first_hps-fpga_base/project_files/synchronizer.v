// =============================================================================
// Módulo: synchronizer.v
//
// Descrição:
// Um módulo genérico para sincronizar um barramento de dados de um domínio
// de clock de origem para um domínio de clock de destino. Utiliza um
// sincronizador de 2 estágios (2 flip-flops) para mitigar a metastabilidade,
// que é a causa principal de erros de sincronização.
//
// Parâmetros:
//   - WIDTH: A largura em bits do barramento a ser sincronizado.
// =============================================================================

module synchronizer #(
    parameter WIDTH = 1 // A largura padrão é 1 bit
) (
    input  wire             clk,      // Clock do domínio de destino (seu clock_25)
    input  wire             reset,    // Reset para o domínio de destino
    input  wire [WIDTH-1:0] data_in,  // Barramento de dados assíncrono (a entrada "perigosa")
    output wire [WIDTH-1:0] data_out  // Barramento de dados sincronizado (a saída "segura")
);

    // Registradores para os dois estágios da "zona de quarentena"
    reg [WIDTH-1:0] sync_stage1;
    reg [WIDTH-1:0] sync_stage2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_stage1 <= 0;
            sync_stage2 <= 0;
        end else begin
            // Pipeline de dois estágios:
            // 1. O primeiro estágio captura o dado de entrada (pode se tornar metaestável).
            sync_stage1 <= data_in;
            // 2. O segundo estágio captura a saída (agora estabilizada) do primeiro.
            sync_stage2 <= sync_stage1;
        end
    end

    // A saída final é a do segundo estágio, que é estável e perfeitamente
    // alinhada com o clock de destino.
    assign data_out = sync_stage2;

endmodule