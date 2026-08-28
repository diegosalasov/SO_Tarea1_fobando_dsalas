NASM := nasm
QEMU := qemu-system-i386
DOSBOX := dosbox

MODE := legacy

SRC_DIR := src/$(MODE)
CLOCK_DIR := $(SRC_DIR)/clock
UTILS_DIR := $(SRC_DIR)/utils
BUILD_DIR := build/$(MODE)

BOOT_SRC := $(SRC_DIR)/boot/boot.asm
APP_SRC := $(CLOCK_DIR)/app.asm

BOOT_BIN := $(BUILD_DIR)/boot.bin
APP_BIN := $(BUILD_DIR)/app.bin
APP_COM := $(BUILD_DIR)/reloj.com
DISK_IMG := $(BUILD_DIR)/disk.img

CLOCK_SOURCES := $(wildcard $(CLOCK_DIR)/*.asm) \
	$(wildcard $(CLOCK_DIR)/include/*.inc)
BOOT_SOURCES := $(BOOT_SRC) $(wildcard $(UTILS_DIR)/*.asm)

APP_ASM_FLAGS := -f bin -I$(CLOCK_DIR)/include/ -I$(CLOCK_DIR)/

.PHONY: all app build prog test run run-test debug disasm clean dirs

all: build


# ============================================================
# Directorios de salida
# ============================================================

dirs:
	@mkdir -p $(BUILD_DIR)


# ============================================================
# Aplicacion Legacy
# ============================================================

app: $(APP_BIN)

prog: app

$(APP_BIN): $(CLOCK_SOURCES) | dirs
	$(NASM) $(APP_ASM_FLAGS) $(APP_SRC) -o $(APP_BIN)


# ============================================================
# Bootloader e imagen booteable
# ============================================================

$(BOOT_BIN): $(BOOT_SOURCES) $(APP_BIN) | dirs
	@app_size=$$(wc -c < "$(APP_BIN)"); \
	app_sectors=$$(( ($$app_size + 511) / 512 )); \
	if [ "$$app_sectors" -gt 17 ]; then \
		echo "ERROR: app.bin ocupa $$app_sectors sectores; el limite de esta carga CHS es 17."; \
		exit 1; \
	fi; \
	echo "Ensamblando bootloader para cargar $$app_sectors sectores..."; \
	$(NASM) -f bin -I./ -DAPP_SECTORS=$$app_sectors $(BOOT_SRC) -o $(BOOT_BIN)

$(DISK_IMG): $(BOOT_BIN) $(APP_BIN) | dirs
	dd if=/dev/zero of=$(DISK_IMG) bs=512 count=2880 status=none
	dd if=$(BOOT_BIN) of=$(DISK_IMG) bs=512 seek=0 conv=notrunc status=none
	dd if=$(APP_BIN) of=$(DISK_IMG) bs=512 seek=1 conv=notrunc status=none

build: $(DISK_IMG)


# ============================================================
# Ejecucion y depuracion en QEMU
# ============================================================

run: build
	$(QEMU) -drive format=raw,file=$(DISK_IMG)

debug: build
	$(QEMU) \
		-drive format=raw,file=$(DISK_IMG) \
		-S \
		-gdb tcp::1234


# ============================================================
# Version temporal para DOSBox
# ============================================================

test: $(APP_COM)

$(APP_COM): $(CLOCK_SOURCES) | dirs
	$(NASM) -DDOS_TEST=1 $(APP_ASM_FLAGS) $(APP_SRC) -o $(APP_COM)

run-test: test
	$(DOSBOX) \
		-c "mount c ." \
		-c "c:" \
		-c "cd build/legacy" \
		-c "reloj.com" \
		-c "exit"


# ============================================================
# Utilidades
# ============================================================

disasm: app
	ndisasm -b 16 $(APP_BIN)

clean:
	rm -rf $(BUILD_DIR)
