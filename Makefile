NASM := nasm
DOSBOX := dosbox
LLD_LINK := lld-link

MODE ?= legacy

SRC_DIR := src/$(MODE)
CLOCK_DIR := $(SRC_DIR)/clock
BUILD_DIR := build/$(MODE)

APP_SRC := $(CLOCK_DIR)/app.asm

CLOCK_SOURCES := $(wildcard $(CLOCK_DIR)/*.asm) \
	$(wildcard $(CLOCK_DIR)/include/*.inc)


.PHONY: all app build prog run clean dirs

all: build


# ============================================================
# Directorios de salida
# ============================================================

dirs:
	@mkdir -p $(BUILD_DIR)


# ============================================================
# LEGACY
# ============================================================

ifeq ($(MODE),legacy)

QEMU := qemu-system-i386

UTILS_DIR := $(SRC_DIR)/utils

BOOT_SRC := $(SRC_DIR)/boot/boot.asm

BOOT_BIN := $(BUILD_DIR)/boot.bin
APP_BIN := $(BUILD_DIR)/app.bin
APP_COM := $(BUILD_DIR)/reloj.com
DISK_IMG := $(BUILD_DIR)/disk.img

BOOT_SOURCES := $(BOOT_SRC) $(wildcard $(UTILS_DIR)/*.asm)

APP_ASM_FLAGS := -f bin \
	-I$(CLOCK_DIR)/include/ \
	-I$(CLOCK_DIR)/


.PHONY: test run-test debug disasm


# ============================================================
# Aplicacion Legacy
# ============================================================

app: $(APP_BIN)

prog: app


$(APP_BIN): $(CLOCK_SOURCES) | dirs
	$(NASM) $(APP_ASM_FLAGS) $(APP_SRC) -o $(APP_BIN)


# ============================================================
# Bootloader e imagen booteable Legacy
# ============================================================

$(BOOT_BIN): $(BOOT_SOURCES) $(APP_BIN) | dirs
	@app_size=$$(wc -c < "$(APP_BIN)"); \
	app_sectors=$$(( ($$app_size + 511) / 512 )); \
	if [ "$$app_sectors" -gt 17 ]; then \
		exit 1; \
	fi; \
	$(NASM) -f bin \
		-I./ \
		-DAPP_SECTORS=$$app_sectors \
		$(BOOT_SRC) \
		-o $(BOOT_BIN)


$(DISK_IMG): $(BOOT_BIN) $(APP_BIN) | dirs
	dd if=/dev/zero \
		of=$(DISK_IMG) \
		bs=512 \
		count=2880 \
		status=none

	dd if=$(BOOT_BIN) \
		of=$(DISK_IMG) \
		bs=512 \
		seek=0 \
		conv=notrunc \
		status=none

	dd if=$(APP_BIN) \
		of=$(DISK_IMG) \
		bs=512 \
		seek=1 \
		conv=notrunc \
		status=none


build: $(DISK_IMG)


# ============================================================
# Ejecucion Legacy
# ============================================================

run: build
	$(QEMU) \
		-drive file=$(DISK_IMG),format=raw,if=floppy \
		-boot a \
		-rtc base=localtime


# ============================================================
# Depuracion Legacy
# ============================================================

debug: build
	$(QEMU) \
		-drive file=$(DISK_IMG),format=raw,if=floppy \
		-boot a \
		-rtc base=localtime \
		-S \
		-gdb tcp::1234


# ============================================================
# Version temporal DOSBox
# ============================================================

test: $(APP_COM)


$(APP_COM): $(CLOCK_SOURCES) | dirs
	$(NASM) \
		-DDOS_TEST=1 \
		$(APP_ASM_FLAGS) \
		$(APP_SRC) \
		-o $(APP_COM)


run-test: test
	$(DOSBOX) \
		-c "mount c ." \
		-c "c:" \
		-c "cd build/legacy" \
		-c "reloj.com" \
		-c "exit"


# ============================================================
# Desensamblado Legacy
# ============================================================

disasm: app
	ndisasm -b 16 $(APP_BIN)


# ============================================================
# UEFI
# ============================================================

else ifeq ($(MODE),uefi)

QEMU := qemu-system-x86_64

APP_OBJ := $(BUILD_DIR)/clock.obj
APP_EFI := $(BUILD_DIR)/clock.efi
DISK_IMG := $(BUILD_DIR)/uefi.img

OVMF_CODE := /usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS_TEMPLATE := /usr/share/OVMF/OVMF_VARS_4M.fd
OVMF_VARS := $(BUILD_DIR)/OVMF_VARS.fd


# ============================================================
# Aplicacion UEFI
# ============================================================

app: $(APP_EFI)

prog: app


$(APP_OBJ): $(CLOCK_SOURCES) | dirs
	$(NASM) \
		-f win64 \
		-I$(CLOCK_DIR)/include/ \
		-I$(CLOCK_DIR)/ \
		$(APP_SRC) \
		-o $(APP_OBJ)


$(APP_EFI): $(APP_OBJ)
	$(LLD_LINK) \
		/nologo \
		/subsystem:efi_application \
		/entry:efi_main \
		/machine:x64 \
		/nodefaultlib \
		/dll \
		/out:$(APP_EFI) \
		$(APP_OBJ)


$(OVMF_VARS): | dirs
	cp $(OVMF_VARS_TEMPLATE) $(OVMF_VARS)


# ============================================================
# Imagen FAT UEFI
# ============================================================

$(DISK_IMG): $(APP_EFI) | dirs
	dd if=/dev/zero \
		of=$(DISK_IMG) \
		bs=1M \
		count=64 \
		status=none

	mkfs.fat -F 32 $(DISK_IMG)

	mmd -i $(DISK_IMG) ::/EFI
	mmd -i $(DISK_IMG) ::/EFI/BOOT

	mcopy -i $(DISK_IMG) \
		$(APP_EFI) \
		::/EFI/BOOT/BOOTX64.EFI


build: $(DISK_IMG) $(OVMF_VARS)


# ============================================================
# Ejecucion UEFI
# ============================================================

run: build
	$(QEMU) \
		-machine q35 \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive if=pflash,format=raw,file=$(OVMF_VARS) \
		-drive format=raw,file=$(DISK_IMG) \
		-rtc base=localtime


# ============================================================
# Modo invalido
# ============================================================

else

$(error MODE debe ser legacy o uefi)

endif


# ============================================================
# Limpieza
# ============================================================

clean:
	rm -rf $(BUILD_DIR)