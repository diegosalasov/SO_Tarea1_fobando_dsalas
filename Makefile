NASM := nasm

SRC_DIR := src
INC_DIR := include
BUILD_DIR := build

APP_SRC := $(SRC_DIR)/app.asm

APP_BIN := $(BUILD_DIR)/reloj.bin
APP_COM := $(BUILD_DIR)/reloj.com

ASM_FLAGS := -f bin -I$(INC_DIR)/ -I$(SRC_DIR)/

SOURCES := $(wildcard $(SRC_DIR)/*.asm)
INCLUDES := $(wildcard $(INC_DIR)/*.inc)


.PHONY: all app test run clean disasm


all: app


# ============================================================
# Aplicacion real
# ============================================================

app: $(APP_BIN)


$(APP_BIN): $(SOURCES) $(INCLUDES)
	@mkdir -p $(BUILD_DIR)
	$(NASM) $(ASM_FLAGS) $(APP_SRC) -o $(APP_BIN)


# ============================================================
# Version temporal para DOSBox
# ============================================================

test: $(APP_COM)


$(APP_COM): $(SOURCES) $(INCLUDES)
	@mkdir -p $(BUILD_DIR)
	$(NASM) -DDOS_TEST=1 $(ASM_FLAGS) $(APP_SRC) -o $(APP_COM)


# ============================================================
# Ejecutar prueba
# ============================================================

run: test
	dosbox \
		-c "mount c ." \
		-c "c:" \
		-c "cd build" \
		-c "reloj.com" \
		-c "exit"


# ============================================================
# Desensamblar el binario real
# ============================================================

disasm: app
	ndisasm -b 16 $(APP_BIN)


# ============================================================
# Limpiar
# ============================================================

clean:
	rm -rf $(BUILD_DIR)