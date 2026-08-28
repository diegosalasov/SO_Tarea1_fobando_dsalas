# Tools
ASM  = nasm
QEMU = qemu-system-i386
GDB  = gdb

# Targets
MODE = legacy

# Diretories
SRC_DIR   = src/$(MODE)
BUILD_DIR  = build/$(MODE)

# Files
BOOT = $(SRC_DIR)/boot/boot.asm
IMG  = $(BUILD_DIR)/disk.img
BIN  = $(BUILD_DIR)/boot.bin

.PHONY: all build run debug clean

all: build

# Make directories if they don't exist
dirs:
	@echo "Creating build directories... ($(MODE) mode)"
	mkdir -p $(BUILD_DIR)

# Assemble bootloader and create disk image
build: dirs
	@echo "Building bootloader... ($(MODE) mode)"
	$(ASM) -f bin $(BOOT) -o $(BIN)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(BIN) of=$(IMG) conv=notrunc

# Run normally
run: build
	@echo "Running QEMU... ($(MODE) mode)"
	$(QEMU) -drive format=raw,file=$(IMG)

# Run QEMU waiting for GDB
debug: build
	@echo "Running QEMU in debug mode... ($(MODE) mode)"
	$(QEMU) \
		-drive format=raw,file=$(IMG) \
		-S \
		-gdb tcp::1234

# Remove generated files
clean:
	@echo "Cleaning generated files... ($(MODE) mode)"
	rm -f $(BIN) $(IMG)
	@echo "Done."