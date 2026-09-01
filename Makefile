# Tools
ASM  = nasm
QEMU = qemu-system-i386
QEMU64 = qemu-system-x86_64
GDB  = gdb
LD   = x86_64-w64-mingw32-ld

OVMF      = /usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS = /usr/share/OVMF/OVMF_VARS_4M.fd

# Targets
MODE ?= legacy

# Diretories
SRC_DIR   = src/$(MODE)
BUILD_DIR = build/$(MODE)
BIN_DIR	  = bin/$(MODE)

ESP_DIR   = $(BUILD_DIR)/esp
EFI_DIR	  = $(ESP_DIR)/EFI/BOOT

# Files
FILE   = app

BOOT   = $(SRC_DIR)/boot/boot.asm
KERNEL = $(SRC_DIR)/clock/$(FILE).asm

EFI	 = $(EFI_DIR)/BOOTX64.efi
IMG  = $(BUILD_DIR)/disk.img

BOOT_BIN   = $(BUILD_DIR)/boot.bin
BOOT_OBJ   = $(BUILD_DIR)/boot.obj
KERNEL_BIN = $(BIN_DIR)/$(FILE).bin

VARS = $(BUILD_DIR)/OVMF_VARS_4M.fd

all: build

# Make directories if they don't exist
dirs:
	@echo "Creating directories for build and binaries... ($(MODE) mode)"
	mkdir -p $(BUILD_DIR) $(BIN_DIR)
	@if [ "$(MODE)" = "uefi" ]; then \
		mkdir -p $(EFI_DIR); \
	fi 
	@echo "[DONE]"
	@echo


# Compile programs
program:
	@echo "Creating program binaries..."
	@echo "> Compiling kernel: clock"
	$(ASM) -f bin $(KERNEL) -o $(KERNEL_BIN)
	@echo "Compiling finished!"
	@echo "[DONE]"
	@echo

# Assemble bootloader and create disk image
build: dirs program
	@echo "Building bootloader..."
	@echo "[MODE = $(MODE)]"
	@if [ "$(MODE)" = "legacy" ]; then \
        echo "Compiling bootloader binaries..."; \
		$(ASM) -f bin $(BOOT) -o $(BOOT_BIN); \
		echo "Building image..."; \
		dd if=/dev/zero of=$(IMG) bs=512 count=2880; \
		dd if=$(BOOT_BIN)  of=$(IMG) bs=512 seek=0 conv=notrunc; \
		dd if=$(KERNEL_BIN) of=$(IMG) bs=512 seek=1 conv=notrunc; \
	elif [ "$(MODE)" = "uefi" ]; then \
		echo "Copying OVMF vars to build directory..."; \
		cp "$(OVMF_VARS)" "$(VARS)"; \
        echo "Generating bootloader object code..."; \
		$(ASM) -f win64 $(BOOT) -o $(BOOT_OBJ); \
		echo "Linking object code..."; \
		$(LD) --subsystem 10 --entry efi_main -o $(EFI) $(BOOT_OBJ); \
		echo "Moving kernel to ESP dir"; \
		cp "$(KERNEL_BIN)" "$(ESP_DIR)/$(FILE).bin"; \
    else \
        echo "ERROR: Unknown mode"; \
    fi
	@echo "Finished building bootloader!"
	@echo "[DONE]"
	@echo

# Run normally
run: build
	@echo "Running QEMU... ($(MODE) mode)"
	@if [ "$(MODE)" = "legacy" ]; then \
		$(QEMU) -drive format=raw,file=$(IMG); \
	elif [ "$(MODE)" = "uefi" ]; then \
		$(QEMU64) \
		-machine q35 \
		-m 128M \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF) \
		-drive if=pflash,format=raw,file=$(VARS) \
		-drive format=raw,file=fat:rw:$(ESP_DIR),if=virtio; \
	else \
		echo "ERROR: Unknown mode"; \
	fi

# Run QEMU waiting for GDB
debug: build
	@echo "Running QEMU in debug mode... ($(MODE) mode)"
	@if [ "$(MODE)" = "legacy" ]; then \
		$(QEMU) -drive format=raw,file=$(IMG) -S -gdb tcp::1234; \
	elif [ "$(MODE)" = "uefi" ]; then \
		$(QEMU64) \
		-machine q35 \
		-m 128M \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF) \
		-drive if=pflash,format=raw,file=$(VARS) \
		-drive format=raw,file=fat:rw:$(ESP_DIR),if=virtio \
		-s \
		-S ;\
	else \
		echo "ERROR: Unknown mode"; \
	fi

# Remove generated files
clean:
	@echo "Cleaning generated files... ($(MODE) mode)"
	rm -r $(BUILD_DIR) $(BIN_DIR)
	@echo "Done."

.PHONY: all build run debug clean