// ================================================================================
// Módulo: instruction_strobe_detector.v
//
// Descrição:
// Este módulo desempenha um papel crucial na interface entre o HPS e a lógica da
// FPGA. O HPS escreve uma instrução de 32 bits no barramento PIO, mas não há um
// sinal de "escrita concluída" explícito. Este módulo resolve esse problema
// monitorando o barramento de instruções e gerando um pulso de um único ciclo
// (`strobe_out`) sempre que o valor no barramento muda.
//
// Funcionamento:
// 1. Ele armazena o valor do `instruction_bus` do ciclo de clock anterior em um
//    registrador (`instruction_bus_r`).
// 2. Em cada ciclo de clock, ele compara o valor atual do `instruction_bus` com
//    o valor armazenado (`instruction_bus_r`).
// 3. Se os valores forem diferentes, significa que o HPS escreveu um novo dado.
//    Nesse momento, a saída `strobe_out` é ativada (vai para '1') por exatamente
//    um ciclo.
// 4. No ciclo seguinte, `instruction_bus_r` é atualizado com o novo valor,
//    fazendo com que a comparação resulte em igualdade novamente, e `strobe_out`
//    volta para '0'.
//
// Este pulso "strobe" funciona como uma "campainha" que alerta a `control_unit`
// para que ela processe a nova instrução que acaba de chegar.
// ================================================================================

module instruction_strobe_detector (
	// --- Entradas ---
	input wire        clock,            // Clock do sistema (25MHz).
	input wire        reset,            // Sinal de reset síncrono.
	input wire [31:0] instruction_bus,  // A entrada do barramento PIO (já sincronizada).

	// --- Saída ---
	output wire       strobe_out        // Saída de pulso (a "campainha").
);

	// Registrador para armazenar o valor do barramento do ciclo anterior.
	reg [31:0] instruction_bus_r;

	// Bloco síncrono para atualizar o registrador.
	always @(posedge clock or posedge reset) begin
		if (reset) begin
			instruction_bus_r <= 32'd0; // Inicializa com um valor conhecido.
		end else begin
			// A cada ciclo de clock, `instruction_bus_r` recebe o valor
			// que estava em `instruction_bus` no ciclo atual.
			instruction_bus_r <= instruction_bus;
		end
	end

	// --- Lógica Combinacional de Comparação ---
	// O strobe é ativado (vai para '1') apenas no exato ciclo em que o valor atual
	// do barramento é diferente do valor do ciclo anterior.
	assign strobe_out = (instruction_bus != instruction_bus_r);

endmodule