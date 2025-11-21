// ================================================================================
// Módulo: control_unit.v
//
// Descrição:
// Este módulo funciona como a unidade de controle central ou o "cérebro" do
// processador de imagem. Sua principal responsabilidade é gerenciar o estado
// geral do sistema e traduzir as instruções recebidas do HPS em comandos
// para a `processing_unit` e o `video_controller`.
//
// Funcionalidades Principais:
// 1. Implementa uma máquina de estados finitos (FSM) com dois estados:
//    - `WAITING`: O sistema está ocioso, aguardando uma nova instrução do HPS.
//    - `PROCESSING`: O sistema está ocupado executando uma operação de imagem.
// 2. No reset, inicia automaticamente uma operação `ORIGINAL` para carregar a
//    imagem padrão da `ram_image` para a `ram_op`, garantindo que algo seja
//    exibido na tela ao ligar.
// 3. Monitora o sinal `instruction_strobe` para detectar a chegada de uma nova
//    instrução.
// 4. Decodifica o `opcode` da instrução para determinar a ação a ser tomada.
// 5. Atualiza os registradores de seleção de algoritmo (`zoom_in_algo_select`
//    e `zoom_out_algo_select`) com base nas instruções recebidas.
// 6. Ao receber uma instrução que requer processamento (como zoom ou upload),
//    ele transita para o estado `PROCESSING` e define a `operation` apropriada
//    para a `processing_unit`.
// 7. No estado `PROCESSING`, aguarda o sinal `processing_done` da `processing_unit`
//    para saber quando a tarefa foi concluída.
// 8. Após a conclusão de uma operação, atualiza o `display_mode` para corresponder
//    à nova resolução da imagem e retorna ao estado `WAITING`.
// ================================================================================

module control_unit (
	// --- Entradas ---
	input wire clock,                 // Clock do sistema (25MHz).
	input wire reset,                 // Sinal de reset síncrono.
	input wire [31:0] instruction_in, // Barramento de instrução de 32 bits vindo do HPS.
	input wire        instruction_strobe, // Pulso indicando que uma nova instrução chegou.
	input wire        processing_done,    // Pulso da `processing_unit` indicando o fim de uma operação.

	// --- Saídas de Controle ---
	output reg         program_state,       // Estado atual do sistema (0=WAITING, 1=PROCESSING).
	output reg [2:0]   operation,         // Código da operação a ser executada pela `processing_unit`.
	output reg [2:0]   display_mode,      // Modo de exibição para o `video_controller`.
	output reg         zoom_in_algo_select,  // Seletor de algoritmo para zoom in (0=Replication, 1=NN).
	output reg         zoom_out_algo_select  // Seletor de algoritmo para zoom out (0=Decimation, 1=BA).
);

	// --- DEFINIÇÕES DA ISA (Instruction Set Architecture) v4 ---
	// Mapeia os 3 bits mais significativos da instrução para um opcode.
	wire [2:0] opcode = instruction_in[31:29];

	// Definição dos opcodes para cada instrução.
	localparam OP_NOP            = 3'b000; // Nenhuma operação.
	localparam OP_ZOOM_IN        = 3'b001; // Comando para aplicar zoom in.
	localparam OP_ZOOM_OUT       = 3'b010; // Comando para aplicar zoom out.
	localparam OP_REPLICATION    = 3'b011; // Configura o algoritmo de zoom in para Replicação.
	localparam OP_DECIMATION     = 3'b100; // Configura o algoritmo de zoom out para Dizimação.
	localparam OP_NEAREST_NEIGHBOR = 3'b101; // Configura o algoritmo de zoom in para Vizinho Mais Próximo.
	localparam OP_BLOCK_AVERAGE  = 3'b110; // Configura o algoritmo de zoom out para Média de Bloco.
	localparam OP_UPLOAD_IMAGE   = 3'b111; // Comando para uma operação de upload de pixel.

	// --- Estados e Operações Internas ---
	// Mapeamento dos estados da FSM.
	localparam WAITING    = 1'b0;
	localparam PROCESSING = 1'b1;
	
	// Mapeamento dos códigos de operação/display para maior legibilidade.
	localparam ZOOM_OUT_4X = 3'b000, ZOOM_OUT_2X = 3'b001, ORIGINAL = 3'b010;
	localparam ZOOM_IN_2X  = 3'b011, ZOOM_IN_4X  = 3'b100;
	localparam UPLOAD      = 3'b101; // Código interno para a operação de upload.

	// Registrador de estado para a máquina de estados.
	reg state;

	// ================================================================
	// LÓGICA SÍNCRONA (MÁQUINA DE ESTADOS)
	// ================================================================
	always @(posedge clock or posedge reset) begin
		 if (reset) begin
			  // --- Estado de Inicialização (Auto-Execução) ---
			  // Ao resetar, o sistema não fica parado. Ele entra diretamente
			  // no estado de processamento para executar a operação 'ORIGINAL'.
			  // Isso garante que a imagem padrão (do arquivo .mif) seja copiada
			  // para a RAM de operação e exibida assim que o sistema liga.
			  state                <= PROCESSING;
			  operation            <= ORIGINAL;
			  display_mode         <= ORIGINAL;
			  
			  // Valores padrão para os seletores de algoritmo.
			  zoom_in_algo_select  <= 1'b0; // Default: Replication
			  zoom_out_algo_select <= 1'b0; // Default: Decimation
			  
			  program_state        <= WAITING; // `program_state` reflete o estado ANTERIOR, então começa em 0.
			  
		 end else begin
			  // A saída `program_state` simplesmente espelha o valor do registrador de estado.
			  program_state <= state;

			  case(state)
					// --- ESTADO DE ESPERA ---
					WAITING: begin
						 if (instruction_strobe) begin // Se uma nova instrução chegou...
							  case (opcode)
									// --- Comandos de Zoom ---
									OP_ZOOM_IN: begin
										 // Só executa se não estiver no zoom máximo.
										 if (display_mode != ZOOM_IN_4X) begin
											  state <= PROCESSING; // Muda para o estado de processamento.
											  // Determina a próxima operação baseada no modo de exibição atual.
											  case(display_mode)
													ZOOM_OUT_4X: operation <= ZOOM_OUT_2X;
													ZOOM_OUT_2X: operation <= ORIGINAL;
													ORIGINAL:    operation <= ZOOM_IN_2X;
													default:     operation <= ZOOM_IN_4X;
											  endcase
										 end
									end
									OP_ZOOM_OUT: begin
										 // Só executa se não estiver no zoom mínimo.
										 if (display_mode != ZOOM_OUT_4X) begin
											  state <= PROCESSING; // Muda para o estado de processamento.
											  case(display_mode)
													ZOOM_IN_4X:  operation <= ZOOM_IN_2X;
													ZOOM_IN_2X:  operation <= ORIGINAL;
													ORIGINAL:    operation <= ZOOM_OUT_2X;
													default:     operation <= ZOOM_OUT_4X;
											  endcase
										 end
									end
									
									// --- Comando de Upload ---
									OP_UPLOAD_IMAGE: begin
									    state <= PROCESSING;
									    operation <= UPLOAD;
									end

									// --- Comandos de Configuração de Algoritmo ---
									// Estas instruções apenas mudam o valor de um registrador
									// e não iniciam um processamento. O estado permanece `WAITING`.
									OP_REPLICATION:    zoom_in_algo_select  <= 1'b0;
									OP_NEAREST_NEIGHBOR: zoom_in_algo_select  <= 1'b1;
									OP_DECIMATION:     zoom_out_algo_select <= 1'b0;
									OP_BLOCK_AVERAGE:  zoom_out_algo_select <= 1'b1;

									default: begin /* NOP, nenhuma ação */ end
							  endcase
						 end
					end
					
					// --- ESTADO DE PROCESSAMENTO ---
					PROCESSING: begin
						 if (processing_done) begin // Se a `processing_unit` terminou...
							  state <= WAITING; // Retorna ao estado de espera.
							  
							  // --- Lógica de Atualização do Display Pós-Processamento ---
							  // É crucial atualizar o `display_mode` para que o `video_controller`
							  // saiba o tamanho da nova imagem a ser exibida.
							  if (operation == UPLOAD) begin
							      // Após um upload, a imagem é sempre 160x120.
								  // Força o modo de exibição para ORIGINAL.
							      display_mode <= ORIGINAL;
							  end else begin
							      // Para as outras operações (zoom, original), o novo modo de
								  // exibição é o mesmo que a operação que acabou de ser concluída.
							      display_mode <= operation;
							  end
						 end
					end
			  endcase
		 end
	end
endmodule