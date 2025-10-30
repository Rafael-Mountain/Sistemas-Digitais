// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ... (cabeçalho de licença e disclaimer) ...
// ============================================================================

`define ENABLE_HPS

module ghrd_top(

      ///////// ADC /////////
      output             ADC_CONVST,
      output             ADC_DIN,
      input              ADC_DOUT,
      output             ADC_SCLK,

      ///////// AUD /////////
      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

      ///////// CLOCK /////////
      input              CLOCK_50,

      ///////// GPIO /////////
      inout     [35:0]         GPIO_0,
      inout     [35:0]         GPIO_1,
 
      ///////// HEX0-5 /////////
      output      [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      // ... (todas as portas HPS, DRAM, etc. permanecem as mesmas)
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// KEY /////////
      input       [3:0]  KEY,

      ///////// LEDR /////////
      output      [9:0]  LEDR,

      ///////// SW /////////
      input       [9:0]  SW,

      ///////// VGA /////////
      output      [7:0]  VGA_B,
      output             VGA_BLANK_N,
      output             VGA_CLK,
      output      [7:0]  VGA_G,
      output             VGA_HS,
      output      [7:0]  VGA_R,
      output             VGA_SYNC_N,
      output             VGA_VS
);

//=======================================================
//  REG/WIRE DECLARATIONS
//=======================================================

// Conexões entre o HPS (via Qsys) e o seu módulo 'main'
wire [31:0] hps_instruction;
wire        hps_begin_flag;
wire        hps_done_flag;

// Fios para as saídas VGA do seu módulo 'main'
wire        vga_hsync_w;
wire        vga_vsync_w;
wire [7:0]  vga_r_w;
wire [7:0]  vga_g_w;
wire [7:0]  vga_b_w;
wire        vga_clk_w;
wire        vga_blank_w;
wire        vga_sync_w;

wire hps_fpga_reset_n; // Reset vindo do HPS (ativo baixo)
wire fpga_reset;       // Reset final para o seu módulo (ativo alto)
        
assign fpga_reset = !hps_fpga_reset_n;


//=======================================================
//  SOC SYSTEM INSTANCE
//=======================================================
soc_system u0 (
    .clk_clk                               ( CLOCK_50         ),      // clk.clk
    .reset_reset_n                         ( hps_fpga_reset_n ),      // reset.reset_n

    // --- HPS DDR3 Memory and other peripherals ---
    .memory_mem_a                          ( HPS_DDR3_ADDR  ),
    .memory_mem_ba                         ( HPS_DDR3_BA    ),
    .memory_mem_ck                         ( HPS_DDR3_CK_P  ),
    .memory_mem_ck_n                       ( HPS_DDR3_CK_N  ),
    .memory_mem_cke                        ( HPS_DDR3_CKE   ),
    .memory_mem_cs_n                       ( HPS_DDR3_CS_N  ),
    .memory_mem_ras_n                      ( HPS_DDR3_RAS_N ),
    .memory_mem_cas_n                      ( HPS_DDR3_CAS_N ),
    .memory_mem_we_n                       ( HPS_DDR3_WE_N  ),
    .memory_mem_reset_n                    ( HPS_DDR3_RESET_N   ),
    .memory_mem_dq                         ( HPS_DDR3_DQ    ),
    .memory_mem_dqs                        ( HPS_DDR3_DQS_P ),
    .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N ),
    .memory_mem_odt                        ( HPS_DDR3hps_begin_flag_ODT   ),
    .memory_mem_dm                         ( HPS_DDR3_DM    ),
    .memory_oct_rzqin                      ( HPS_DDR3_RZQ   ),
    .hps_0_hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK),
    .hps_0_hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),
    .hps_0_hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),
    .hps_0_hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),
    .hps_0_hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),
    .hps_0_hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),
    .hps_0_hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),
    .hps_0_hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),
    .hps_0_hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV),
    .hps_0_hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN),
    .hps_0_hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK),
    .hps_0_hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),
    .hps_0_hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),
    .hps_0_hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),
    .hps_0_hps_io_hps_io_qspi_inst_IO0     ( HPS_FLASH_DATA[0]    ),
    .hps_0_hps_io_hps_io_qspi_inst_IO1     ( HPS_FLASH_DATA[1]    ),
    .hps_0_hps_io_hps_io_qspi_inst_IO2     ( HPS_FLASH_DATA[2]    ),
    .hps_0_hps_io_hps_io_qspi_inst_IO3     ( HPS_FLASH_DATA[3]    ),
    .hps_0_hps_io_hps_io_qspi_inst_SS0     ( HPS_FLASH_NCSO    ),
    .hps_0_hps_io_hps_io_qspi_inst_CLK     ( HPS_FLASH_DCLK    ),
    .hps_0_hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD    ),
    .hps_0_hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0]     ),
    .hps_0_hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1]     ),
    .hps_0_hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK   ),
    .hps_0_hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2]     ),
    .hps_0_hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3]     ),
    .hps_0_hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6]    ),
    .hps_0_hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7]    ),
    .hps_0_hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT    ),
    .hps_0_hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP    ),
    .hps_0_hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_hps_begin_flagDIR    ),
    .hps_0_hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT    ),
    .hps_0_hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK  ),
    .hps_0_hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),
    .hps_0_hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),
    .hps_0_hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS ),
    .hps_0_hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX    ),
    .hps_0_hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX    ),
    .hps_0_hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C1_SDAT    ),
    .hps_0_hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C1_SCLK    ),
    .hps_0_hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C2_SDAT    ),
    .hps_0_hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C2_SCLK    ),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO48  ( HPS_I2C_CONTROL),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY),
    .hps_0_hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT),
    .hps_0_h2f_reset_reset_n               (hps_fpga_reset_n),

    .pio_instruction_external_connection_export (hps_instruction),
    .pio_done_external_connection_export        (hps_done_flag),
	 .pio_instruction_write								(hps_begin_flag)
);

//=======================================================
//  CONEXÕES DE PINOS FÍSICOS
//=======================================================

assign VGA_HS      = vga_hsync_w;
assign VGA_VS      = vga_vsync_w;
assign VGA_R       = vga_r_w;
assign VGA_G       = vga_g_w;
assign VGA_B       = vga_b_w;
assign VGA_CLK     = vga_clk_w;
assign VGA_BLANK_N = ~vga_blank_w;
assign VGA_SYNC_N  = ~vga_sync_w;

assign HEX0 = 7'b1111111; assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111; assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111; assign HEX5 = 7'b1111111;
assign LEDR = 10'b0;

//=======================================================
//  INSTÂNCIA DO SEU MÓDULO 'main'
//=======================================================
main image_processor_inst (
    .clock_50       (CLOCK_50),
    .reset_signal   (fpga_reset),
    .instruction    (hps_instruction),
    .begin_flag     (hps_begin_flag),
    .done_flag      (hps_done_flag),
    .hsync          (vga_hsync_w),
    .vsync          (vga_vsync_w),
    .red            (vga_r_w),
    .green          (vga_g_w),
    .blue           (vga_b_w),
    .sync           (vga_sync_w),
    .clk_out        (vga_clk_w),
    .blank          (vga_blank_w)
);

endmodule