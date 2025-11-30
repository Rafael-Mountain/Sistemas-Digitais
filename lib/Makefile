# Nome do arquivo final
TARGET = lib_api

# Arquivos fonte
SRCS = lib_api.s

# Compilador e flags
AS = gcc
ASFLAGS = -c -march=armv7-a -mfpu=vfpv3-d16

LD = gcc
LDFLAGS = 

# Regra padrão
all: $(TARGET)

$(TARGET): $(SRCS)
	$(AS) $(ASFLAGS) -o lib_api.o lib_api.s
	$(LD) $(LDFLAGS) -o $(TARGET) lib_api.o

clean:
	rm -f *.o $(TARGET)
