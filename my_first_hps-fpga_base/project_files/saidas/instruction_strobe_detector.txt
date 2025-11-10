// instruction_strobe_detector.v
// Descrição: Este módulo recebe o barramento de instrução de 32 bits do HPS
// e gera um pulso de um único ciclo de clock na saída 'strobe_out'
// sempre que o valor no barramento muda. Isso sinaliza para o resto
// do sistema que uma nova instrução foi escrita pelo software.

module instruction_strobe_detector (
	input wire        clock,
	input wire        reset,
	input wire [31:0] instruction_bus, // Entrada do PIO de instrução
	output wire       strobe_out       // Saída de pulso (a "campainha")
);

	// Registrador para armazenar o valor do barramento do ciclo anterior
	reg [31:0] instruction_bus_r;

	always @(posedge clock or posedge reset) begin
		if (reset) begin
			instruction_bus_r <= 32'd0;
		end else begin
			instruction_bus_r <= instruction_bus;
		end
	end

	// O strobe é ativo (vai para 1) apenas no ciclo em que o valor atual
	// é diferente do valor do ciclo anterior.
	assign strobe_out = (instruction_bus != instruction_bus_r);

endmodule