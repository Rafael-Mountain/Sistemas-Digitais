// =============================================================================
// Módulo: synchronizer.v
//
// Descrição:
// Um módulo genérico e fundamental para a estabilidade de sistemas digitais.
// Sua função é transferir de forma segura um barramento de dados de um domínio
// de clock de origem (que é assíncrono em relação a este módulo) para um
// domínio de clock de destino.
//
// O Problema (Metastabilidade):
// Quando um sinal de entrada (`data_in`) muda muito perto da borda de subida do
// clock de amostragem (`clk`), o flip-flop que o captura pode entrar em um
// estado metaestável — um estado indefinido entre 0 e 1. Se esse sinal
// instável se propagar pelo sistema, pode causar falhas imprevisíveis.
//
// A Solução (Sincronizador de 2 Estágios):
// Este módulo utiliza uma cadeia de dois flip-flops para
// "isolar" e "curar" a metastabilidade.
// 1. O primeiro flip-flop (`sync_stage1`) captura o dado de entrada. Ele está em
//    risco de se tornar metaestável.
// 2. O segundo flip-flop (`sync_stage2`) captura a saída do primeiro. A chave é
//    que a saída do primeiro flip-flop tem um ciclo de clock inteiro para se
//    resolver em um valor estável (0 ou 1) antes de ser capturada pelo segundo.
// A saída do segundo flip-flop é considerada segura e sincronizada.
//
// Parâmetros:
//   - WIDTH: A largura em bits do barramento a ser sincronizado.
// =============================================================================

module synchronizer #(
    parameter WIDTH = 1 // A largura padrão é 1 bit, mas pode ser redefinida na instanciação.
) (
    // --- Entradas ---
    input  wire             clk,      // Clock do domínio de *destino* (o clock que queremos que os dados sigam).
    input  wire             reset,    // Reset para o domínio de destino.
    input  wire [WIDTH-1:0] data_in,  // Barramento de dados assíncrono (a entrada "perigosa" ou "não confiável").
    
    // --- Saída ---
    output wire [WIDTH-1:0] data_out  // Barramento de dados sincronizado (a saída "segura" e "confiável").
);

    // Registradores para os dois estágios da "zona de quarentena".
    reg [WIDTH-1:0] sync_stage1;
    reg [WIDTH-1:0] sync_stage2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Garante um estado inicial conhecido.
            sync_stage1 <= 0;
            sync_stage2 <= 0;
        end else begin
            // --- Pipeline de dois estágios ---
            
            // 1. O primeiro estágio captura o dado de entrada. Este é o ponto
            //    onde a metastabilidade pode ocorrer.
            sync_stage1 <= data_in;
            
            // 2. O segundo estágio captura a saída (agora estabilizada) do primeiro.
            //    A probabilidade de a metastabilidade durar um ciclo de clock
            //    inteiro é extremamente baixa, tornando a saída de `sync_stage2` segura.
            sync_stage2 <= sync_stage1;
        end
    end

    // A saída final do módulo é a do segundo estágio, que é estável e
    // perfeitamente alinhada com o clock de destino (`clk`).
    assign data_out = sync_stage2;

endmodule