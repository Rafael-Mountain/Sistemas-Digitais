// ================================================================================
// Módulo: main.v
//
// Alterações:
// - Adicionada entrada 'hps_blank_in'.
// - Adicionado Sincronizador para o sinal de Blank.
// - Conectado ao video_controller.
// ================================================================================

module main (
    // --- Entradas Globais ---
    input wire clock_50,        // Clock principal de 50MHz vindo da placa.
    input wire reset_button,    // Botão de reset físico (assíncrono).

    // --- Entradas do HPS e de Controle ---
    input wire [31:0] hps_pio_bus_in,       // Barramento de 32 bits do PIO do HPS (Instruções).
    input wire        debug_display_select, // Chave (SW[0]) para selecionar display 7-seg.
    
    // --- NOVA ENTRADA DE CONTROLE ---
    input wire        hps_blank_in,         // PIO de 1 bit do HPS para apagar a tela.

    // --- SAÍDAS PARA O HPS ---
    output reg [7:0]  hps_pio_data_out,    
    output reg        hps_pio_done_out,    

    // --- Saídas para o Controlador VGA ---
    output wire hsync, vsync,
    output wire [7:0] red, green, blue, 
    output wire sync, clk_out, blank,    
	 
    // --- Saídas de Debug para os LEDs ---
    output wire zoom_in_algo_select_wire,  
    output wire zoom_out_algo_select_wire, 
	 
    // --- Saídas para os Displays de 7 Segmentos ---
    output wire [6:0] seg0_output, seg1_output, seg2_output,
    output wire [6:0] seg3_output, seg4_output, seg5_output
);

    //============================================================================
    // FIOS INTERNOS (WIRES)
    //============================================================================

    wire clock_25;     
    wire reset_sync;   
    
    wire [31:0] hps_pio_bus_sync;
    
    // --- Fio para o Blank Sincronizado ---
    wire hps_blank_sync;

    wire program_state;      
    wire processing_done;    
    wire instruction_strobe; 
    wire [2:0] operation;    
    wire [2:0] display_mode; 
    
    wire zoom_in_algo_select;
    wire zoom_out_algo_select;

    wire [14:0] proc_img_addr;
    wire [7:0]  proc_img_data_in;
    wire        proc_img_wren;
    wire [7:0]  img_q_out;

    wire [18:0] proc_op_addr;       
    wire [18:0] video_ram_address;  
    wire [18:0] final_op_addr;      
    wire [7:0]  proc_op_data_in;    
    wire        proc_op_wren;       
    wire        final_op_wren;      
    wire [7:0]  op_q_out;           

    wire [7:0]  pu_read_data;       

    localparam READ_OP_CODE = 3'b110; 

    //============================================================================
    // INSTÂNCIA DOS MÓDULOS
    //============================================================================

    clock_divider clock_divider_inst (.clock_in(clock_50), .clock_out(clock_25));
    sync_reset_button sync_reset_button_inst (.clock(clock_25), .reset_button_in(reset_button), .reset_sync_out(reset_sync));

    synchronizer #( .WIDTH(32) ) pio_bus_synchronizer (
        .clk(clock_25),
        .reset(reset_sync),
        .data_in(hps_pio_bus_in),
        .data_out(hps_pio_bus_sync)
    );

    // --- NOVO SINCRONIZADOR PARA O BLANK ---
    synchronizer #( .WIDTH(1) ) blank_sync_inst (
        .clk(clock_25),
        .reset(reset_sync),
        .data_in(hps_blank_in),
        .data_out(hps_blank_sync)
    );

    instruction_strobe_detector strobe_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .instruction_bus(hps_pio_bus_sync),
        .strobe_out(instruction_strobe)
    );

    control_unit control_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .instruction_in(hps_pio_bus_sync),
        .instruction_strobe(instruction_strobe),
        .processing_done(processing_done),
        .program_state(program_state), 
        .operation(operation),
        .display_mode(display_mode),
        .zoom_in_algo_select(zoom_in_algo_select),
        .zoom_out_algo_select(zoom_out_algo_select)
    );
    
    processing_unit processing_unit_inst (
        .clock(clock_25),
        .reset(reset_sync),
        .program_state(program_state),
        .operation(operation),
        .instruction_in(hps_pio_bus_sync),
        .zoom_in_algo_select(zoom_in_algo_select),
        .zoom_out_algo_select(zoom_out_algo_select),
        .ram_image_q_out_in(img_q_out),
        .ram_image_addr_out(proc_img_addr),
        .ram_image_data_out(proc_img_data_in),
        .ram_image_wren_out(proc_img_wren),
        .ram_op_addr_out(proc_op_addr),
        .ram_op_data_out(proc_op_data_in),
        .ram_op_wren_out(proc_op_wren),
        .ram_op_q_in(op_q_out),        
        .read_data_out(pu_read_data),  
        .processing_done(processing_done)
    );
    
    assign final_op_addr = (program_state == 1'b1) ? proc_op_addr : video_ram_address;
    assign final_op_wren = (program_state == 1'b1) ? proc_op_wren : 1'b0;

    memory_module mem_inst (
        .clock(clock_25), 
        .image_address(proc_img_addr),
        .image_data_in(proc_img_data_in),
        .image_wren(proc_img_wren),
        .image_q_out(img_q_out),
        .op_address(final_op_addr),
        .op_data_in(proc_op_data_in),
        .op_wren(final_op_wren),
        .op_q_out(op_q_out) 
    );

    // --- Controlador de Vídeo ATUALIZADO ---
    video_controller video_inst (
        .clk(clock_25),
        .reset(reset_sync),
        .display_mode(display_mode),
        .ram_data_in(op_q_out),
        .processing_active(program_state), 
        
        .external_blank(hps_blank_sync), // <--- Conexão do Blank
        
        .ram_addr_out(video_ram_address),   
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), 
        .blue(blue), .sync(sync), .clk_out(clk_out), .blank(blank)
    );

    always @(posedge clock_25 or posedge reset_sync) begin
        if (reset_sync) begin
            hps_pio_data_out <= 8'd0;
            hps_pio_done_out <= 1'b0;
        end else begin
            if (instruction_strobe) begin
                hps_pio_done_out <= 1'b0;
            end
            else if (processing_done && (operation == READ_OP_CODE)) begin
                hps_pio_data_out <= pu_read_data; 
                hps_pio_done_out <= 1'b1;         
            end
        end
    end

    assign zoom_in_algo_select_wire = zoom_in_algo_select;
    assign zoom_out_algo_select_wire = zoom_out_algo_select;

    top_module seven_segment_controller_inst (
        .hps_pio_data   (hps_pio_bus_sync),
        .display_select (debug_display_select),
        .seg0_output    (seg0_output),
        .seg1_output    (seg1_output),
        .seg2_output    (seg2_output),
        .seg3_output    (seg3_output),
        .seg4_output    (seg4_output),
        .seg5_output    (seg5_output)
    );

endmodule