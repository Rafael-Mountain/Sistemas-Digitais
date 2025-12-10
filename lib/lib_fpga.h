#ifndef FPGA_LIB_H
#define FPGA_LIB_H

#include <stdint.h>

// Opcodes
#define INST_NOP               (0b0000 << 28)
#define INST_ZOOM_IN           (0b0001 << 28)
#define INST_ZOOM_OUT          (0b0010 << 28)
#define INST_REPLICATION       (0b0011 << 28)
#define INST_DECIMATION        (0b0100 << 28)
#define INST_NEAREST_NEIGHBOR  (0b0101 << 28)
#define INST_BLOCK_AVERAGE     (0b0110 << 28)
#define INST_UPLOAD_IMAGE      (0b0111 << 28)
#define INST_READ_PIXEL        (0b1000 << 28)

// Funções
extern int fpga_init(void);
extern void fpga_close(void);
extern void fpga_send_action(int instruction);
extern void fpga_set_config(int instruction);
extern void fpga_write_pixel(int address, int pixel_data);
extern int fpga_read_pixel(int address);

// NOVA FUNÇÃO
extern void fpga_set_blank_pio(int enable);

// Helpers
static inline void fpga_cmd_zoom_in(void) { fpga_send_action(INST_ZOOM_IN); }
static inline void fpga_cmd_zoom_out(void) { fpga_send_action(INST_ZOOM_OUT); }
static inline void fpga_conf_replication(void) { fpga_set_config(INST_REPLICATION); }
static inline void fpga_conf_nearest_neighbor(void) { fpga_set_config(INST_NEAREST_NEIGHBOR); }
static inline void fpga_conf_decimation(void) { fpga_set_config(INST_DECIMATION); }
static inline void fpga_conf_block_average(void) { fpga_set_config(INST_BLOCK_AVERAGE); }

#endif