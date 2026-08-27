# Tools
ASM  = nasm
QEMU = qemu-system-i386
GDB  = gdb

# Diretories
LEGACY_DIR = src/legacy
UEFI_DIR   = src/uefi

# Files
BOOT = boot.asm
IMG  = disk.img

# Targets
LEGACY_BOOT = $(LEGACY_DIR)/boot/$(BOOT)

.PHONY: all build run debug clean

all: build

# Assemble bootloader and create disk image
build:
	$(ASM) -f bin $(LEGACY_BOOT) -o boot.bin
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=boot.bin of=$(IMG) conv=notrunc

# Run normally
run: build
	$(QEMU) -drive format=raw,file=$(IMG)

# Run QEMU waiting for GDB
debug: build
	$(QEMU) \
		-drive format=raw,file=$(IMG) \
		-S \
		-gdb tcp::1234

# Remove generated files
clean:
	rm -f boot.bin $(IMG)