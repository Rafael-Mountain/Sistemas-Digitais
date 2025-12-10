# ==========================================
# Makefile Atualizado - Projeto FPGA + Mouse
# ==========================================

# Compilador
CC = gcc

# Nome do executável final
TARGET = fpga_control

# Arquivos do projeto
SRCS_C  = main.c
SRCS_S  = lib_fpga.s
HEADERS = lib_fpga.h

# Objetos gerados (.o)
OBJS = $(SRCS_C:.c=.o) $(SRCS_S:.s=.o)

# Bibliotecas extras
# -lm : Necessário para funções de math.h (fmin, fmax, etc) usadas no tracker
LIBS = -lm

# Flags padrão (Release)
# -Wall: Avisos, -O2: Otimização
CFLAGS = -Wall -O2 -std=c99

# Flags para Debug
# -g: Símbolos de debug, -O0: Sem otimização
DEBUG_FLAGS = -Wall -g -O0

# --- Regras de Construção ---

# 1. Regra padrão (apenas 'make')
all: $(TARGET)

# 2. Linkagem final
# IMPORTANTE: $(LIBS) deve vir APÓS os objetos $(OBJS) para resolver as referências
$(TARGET): $(OBJS)
	@echo "Linkando executavel: $(TARGET)..."
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJS) $(LIBS)

# 3. Compilar main.c
main.o: main.c $(HEADERS)
	@echo "Compilando C: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# 4. Montar lib_fpga.s
%.o: %.s
	@echo "Montando ASM: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# --- Comandos Úteis ---

# Compilar e Rodar
run: $(TARGET)
	@echo "--- Executando (com sudo) ---"
	sudo ./$(TARGET)

# Modo Debug (Limpa, recompila com flags de debug e roda GDB)
debug: clean
	@echo "--- Compilando em modo DEBUG ---"
	$(MAKE) $(TARGET) CFLAGS="$(DEBUG_FLAGS)"
	@echo "--- Iniciando GDB (sudo) ---"
	sudo gdb ./$(TARGET)

# Limpeza
clean:
	@echo "Limpando arquivos..."
	rm -f *.o $(TARGET)

.PHONY: all run debug clean
