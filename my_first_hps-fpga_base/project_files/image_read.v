// ================================================================================
// Módulo: image_read.v
//
// Descrição:
// Executa a leitura de um pixel da RAM OP para o HPS.
// CORREÇÃO: Adicionados estados de espera para compensar a latência de 2 ciclos
// da altsyncram (Output Registered).
//
// Ciclo de Vida:
// 1. S_IDLE:   Recebe comando, coloca endereço na RAM.
// 2. S_REQ:    Endereço estabiliza no barramento.
// 3. S_WAIT_1: (Borda de Clock) RAM captura o endereço. Inicia acesso interno.
// 4. S_WAIT_2: (Borda de Clock) RAM move dado interno para registrador de saída Q.
// 5. S_DONE:   Dado em Q agora é válido. FPGA captura para data_out.
// ================================================================================

module image_read (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [31:0] instruction,
    input wire [7:0]  ram_op_q,      // Dado vindo da RAM
    output reg [18:0] ram_op_addr,   // Endereço para a RAM
    output reg [7:0]  data_out,      // Dado capturado para o HPS
    output reg        done
);

    // Definição dos Estados
    localparam S_IDLE   = 3'd0;
    localparam S_REQ    = 3'd1; 
    localparam S_WAIT_1 = 3'd2; // Espera captura do endereço pela RAM
    localparam S_WAIT_2 = 3'd3; // Espera atualização do registrador de saída da RAM
    localparam S_DONE   = 3'd4; 

    reg [2:0] state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            ram_op_addr <= 19'd0;
            data_out <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Decodifica o endereço da instrução (bits menos significativos)
                        // Ajuste conforme seu protocolo. Assumindo que os 19 bits
                        // de endereço estão na parte baixa ou definidos na instrução.
                        ram_op_addr <= instruction[18:0]; 
                        state <= S_REQ;
                    end
                end

                S_REQ: begin
                    // O endereço já está no barramento ram_op_addr.
                    // Avança para dar tempo ao setup time da RAM.
                    state <= S_WAIT_1;
                end

                S_WAIT_1: begin
                    // Neste ciclo de clock, a RAM captura o endereço.
                    // O dado começa a ser buscado na matriz de memória.
                    state <= S_WAIT_2;
                end

                S_WAIT_2: begin
                    // Neste ciclo de clock, a RAM atualiza o registrador de saída 'q'.
                    // O dado aparecerá na porta 'ram_op_q' LOGO APÓS esta borda.
                    // Portanto, ainda não podemos capturar aqui (setup time violation).
                    // Vamos para o próximo estado capturar.
                    state <= S_DONE;
                end

                S_DONE: begin
                    // Agora o sinal ram_op_q está estável e válido.
                    data_out <= ram_op_q; 
                    done <= 1'b1;
                    
                    // Handshake: Só volta para IDLE quando o sinal de start baixar
                    if (!start) state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule