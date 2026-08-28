# Tools
ASM  = nasm
QEMU = qemu-system-i386
GDB  = gdb

# Targets
MODE = legacy

# Diretories
SRC_DIR   = src/$(MODE)
BUILD_DIR = build/$(MODE)
BIN_DIR	  = bin	

# Files
BOOT = $(SRC_DIR)/boot/boot.asm
APP  = $(SRC_DIR)/clock/app.asm
IMG  = $(BUILD_DIR)/disk.img
BIN  = $(BUILD_DIR)/boot.bin
APPB = $(BUILD_DIR)/app.bin

.PHONY: all build run debug clean

all: build

# Make directories if they don't exist
dirs:
	@echo "Creating build directories... ($(MODE) mode)"
	mkdir -p $(BUILD_DIR)

# Compile programs
prog:
	@echo "Creating program binaries..."
	@echo "Compiling program #1: iterative_sum"
	$(ASM) -f bin $(APP) -o $(APPB)
	@echo "Compiling finished!"

# Assemble bootloader and create disk image
build: dirs prog
	@echo "Building bootloader and disk image... ($(MODE) mode)"
	$(ASM) -f bin $(BOOT) -o $(BIN)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(BIN)  of=$(IMG) bs=512 seek=0 conv=notrunc
	dd if=$(APPB) of=$(IMG) bs=512 seek=1 conv=notrunc

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