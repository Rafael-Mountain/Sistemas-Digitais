// control_unit.v - Versão Corrigida
module control_unit (
    input wire clock,           // Clock principal de 25MHz
    input wire reset_sync,      // Sinal de Reset Sincronizado
    input wire zoom_in_signal,  // Sinal do botão de zoom-in (ativo-alto)
    input wire zoom_out_signal, // Sinal do botão de zoom-out (ativo-alto)
    input wire processing_done, // Sinal de conclusão do processamento

    output wire processing_active,    // Indicador de processamento (WAITING, PROCESSING)
    output reg [1:0] operation,      // Comando de operação (NONE, ORIGINAL, ZOOM_OUT, ZOOM_IN)
    output reg [1:0] display_mode    // Modo de exibição atual (ORIGINAL, ZOOM_OUT, ZOOM_IN)
);
	
    // Codificação dos Estados
    localparam PROCESSING = 1'b1;
    localparam WAITING    = 1'b0;
	
    // Codificação das Operações e Modos de Exibição
    localparam NONE      = 2'b00;
    localparam ORIGINAL  = 2'b01;
    localparam ZOOM_OUT  = 2'b10;
    localparam ZOOM_IN   = 2'b11;

    reg state;    // Registrador de Estado Atual
    reg next_state; // Registrador do Próximo Estado

    // Sinal de saída ativo para o estado PROCESSING
    // Agora esta linha está correta, pois 'processing_active' é um wire
    assign processing_active = state;

    // --- Detecção de Borda/Debounce ---
    reg  zoom_in_r, zoom_in_r_ant;
    reg  zoom_out_r, zoom_out_r_ant;

    // Sincronização dos botões (Atraso de 2 ciclos para debounce)
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
    always @(posedge clock or posedge reset_sync) begin
        if (reset_sync) begin
            // Reset: Inicia forçando a cópia da imagem original
            state          <= PROCESSING;
            operation      <= ORIGINAL;
            display_mode   <= ORIGINAL;
        end else begin
            state <= next_state;

            // A - Definição da nova operação (ocorre na transição WAITING -> PROCESSING)
            if (state == WAITING && next_state == PROCESSING) begin
                
                // 1. Lógica de "Voltar ao Original" (se pressionou o oposto)
                if ((zoom_in_pressed && display_mode == ZOOM_OUT) || (zoom_out_pressed && display_mode == ZOOM_IN)) begin
                    operation <= ORIGINAL;
                end

					// 2. Lógica de Zoom In (se não está em ZOOM_OUT)
                else if(zoom_in_pressed && display_mode != ZOOM_OUT)  begin
                    operation <= ZOOM_IN;
                end
					
                // 3. Lógica de Zoom Out (se não está em ZOOM_IN)
                else if(zoom_out_pressed && display_mode != ZOOM_IN) begin
                    operation <= ZOOM_OUT;
                end
                else begin
                    operation <= NONE;
                end 						  
            end

            // B - Atualização do modo de exibição (após a conclusão do processamento)
            if (state == PROCESSING && processing_done) begin
                case(operation)
                    ZOOM_IN:     display_mode <= ZOOM_IN;
                    ZOOM_OUT:    display_mode <= ZOOM_OUT;
                    default:     display_mode <= ORIGINAL;
                endcase
            end
        end
    end

    // --- Lógica Combinacional (Próximo Estado) ---
    always @(*) begin
        next_state = state;
        case(state)
            WAITING:
                // Transiciona para PROCESSING se um botão for pressionado
                // (Corrigi um parêntese faltando no 'if' original)
                if (zoom_in_pressed || zoom_out_pressed) begin
                    next_state = PROCESSING;
                end
            PROCESSING:
                // Transiciona para WAITING quando o processamento termina
                if (processing_done) begin
                    next_state = WAITING;
                end
        endcase
    end

endmodule