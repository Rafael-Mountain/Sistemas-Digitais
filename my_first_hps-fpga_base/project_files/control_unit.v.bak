module control_unit (
	input wire clock,           // Clock principal de 25MHz
	input wire reset,           // Sinal de Reset Sincronizado
	input wire zoom_out_signal, // Sinal do botão de zoom-out (ativo-alto)
	input wire zoom_in_signal,  // Sinal do botão de zoom-out (ativo-alto)
	input wire processing_done, // Sinal de conclusão de processamento
	
	output wire program_state,    // Estadual atual do programa (WAITING, PROCESSING)
	output reg [1:0] operation,   // Comando de operação (ORIGINAL, ZOOM_OUT, ZOOM_IN, NONE)
	output reg [1:0] display_mode // Modo de exibição atual (ORIGINAL, ZOOM_OUT, ZOOM_IN)
);

	// Codificação dos Estados
	localparam WAITING    = 1'b0;
	localparam PROCESSING = 1'b1;
	
	// Codificação das Operações e Modos de Exibição
	localparam ORIGINAL = 2'b00;
	localparam ZOOM_OUT = 2'b01; 
	localparam ZOOM_IN  = 2'b10;
	localparam NONE     = 2'b11;
	
	reg state;      // Registrador de Estado Atual
	reg next_state; // Registrador do Próximo Estado
	
	// Saída indicando o estado atual do programa
	assign program_state = state;
	
	// --- Detecção de Borda/Debounce ---
	
	reg zoom_in_r, zoom_in_r_ant;
	reg zoom_out_r, zoom_out_r_ant;
	
	// Sincronização dos botões
	 always @(posedge clock) begin
		  zoom_in_r      <= zoom_in_signal;
		  zoom_in_r_ant  <= zoom_in_r;
		  zoom_out_r     <= zoom_out_signal;
		  zoom_out_r_ant <= zoom_out_r;
	 end
	 
	// Geração do pulso 'pressed' na borda de subida (0 -> 1)
	wire zoom_in_pressed  = ~zoom_in_r_ant & zoom_in_r;
	wire zoom_out_pressed = ~zoom_out_r_ant & zoom_out_r;
	
	// --- Lógica Síncrona (Atualização de Estado, Operação e Modo de Exibição) ---
	always @(posedge clock or posedge reset) begin
		if (reset) begin
		
			// Reset: Inicia o processo para mostrar imagem original
			state          <= PROCESSING;
			operation      <= ORIGINAL;
			display_mode   <= ORIGINAL;
			
		end else begin
		
			state <= next_state; // Transição de Estado
			
			// Definição da NOVA OPERAÇÃO (ocorre apenas no ciclo WAITING -> PROCESSING)
			if (state == WAITING && next_state == PROCESSING) begin
			
				// Voltar ao Original (se apertar zoom_in quando estiver em zoom_out)
				if      (zoom_in_pressed  && display_mode == ZOOM_OUT) operation <= ORIGINAL;
				
				// Voltar ao Original (se apertar zoom_out quando estiver em zoom_in)
				else if (zoom_out_pressed && display_mode == ZOOM_IN)  operation <= ORIGINAL;
				
				// Zoom In (se ainda não estiver no modo Zoom In)
				else if (zoom_in_pressed  && display_mode != ZOOM_IN)  operation <= ZOOM_IN;
				
				// Zoom Out (se ainda não estiver no modo Zoom Out)
				else if (zoom_out_pressed && display_mode != ZOOM_OUT) operation <= ZOOM_OUT;
				
				// Nenhuma operação válida
				else                                                   operation <= NONE;
			end
			
			// Atualização do MODO DE EXIBIÇÃO (após o processamento ser concluído)
			if (state == PROCESSING && processing_done) begin
				case(operation)
					ZOOM_IN:     display_mode <= ZOOM_IN;
					ZOOM_OUT:    display_mode <= ZOOM_OUT;
					default:     display_mode <= ORIGINAL;
				endcase
			end
		end
	end

	// --- Lógica Combinacional (Calcula a Próxima Transição) ---
	always @(*) begin
		next_state = state; // Mantém o estado, a menos que haja uma transição
		case(state)
			WAITING:
			
				// Transiciona para PROCESSING se houver um clique que exija uma mudança de modo
				if ((zoom_in_pressed && display_mode != ZOOM_IN) || (zoom_out_pressed && display_mode != ZOOM_OUT)) begin
					next_state = PROCESSING;
				end
				
			PROCESSING:
			
				// Transiciona para WAITING (após o processamento ser concluído)
				if (processing_done) begin
					next_state = WAITING;
				end
				
		endcase
	end

endmodule