# AkibaOS Makefile

BUILD_DIR = build
INCLUDE_DIR = include
KERNEL_DIR = $(BUILD_DIR)/kernel

KERNEL_OUT = $(KERNEL_DIR)/kernel.bin
ISO_OUT = $(BUILD_DIR)/akibaos.iso

ASM_SOURCES = $(shell find boot -name '*.asm')
ASM_OBJECTS = $(patsubst %.asm,$(BUILD_DIR)/%.o,$(ASM_SOURCES))

CPP_SOURCES = $(shell find kernel -name '*.cpp')
CPP_OBJECTS = $(patsubst %.cpp,$(BUILD_DIR)/%.o,$(CPP_SOURCES))

CXX = clang++
CXXFLAGS = -ffreestanding -O2 -Wall -Wextra -fno-exceptions \
           -fno-rtti -std=c++17 -mno-red-zone -mno-mmx -mno-sse \
           -mno-sse2 -mcmodel=kernel -I$(INCLUDE_DIR)

.PHONY: all clean kernel iso run

# Default target
all: iso

# Compile assembly files
$(BUILD_DIR)/%.o: %.asm
	mkdir -p $(dir $@)
	nasm -f elf64 $< -o $@
	@echo "Compiled $< to $@"

# Compile C++ files
$(BUILD_DIR)/%.o: %.cpp
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@
	@echo "Compiled $< to $@"

# Link kernel
kernel: $(ASM_OBJECTS) $(CPP_OBJECTS)
	@echo "Building kernel..."
	mkdir -p $(BUILD_DIR)
	mkdir -p $(KERNEL_DIR)
	ld -n -o $(KERNEL_OUT) -T scripts/linker.ld $(ASM_OBJECTS) $(CPP_OBJECTS)
	@echo "Kernel built successfully at $(KERNEL_OUT)"

# Setup boot environment 
boot_setup: kernel
	mkdir -p $(BUILD_DIR)/boot/grub
	cp scripts/grub/grub.cfg $(BUILD_DIR)/boot/grub/

# Create bootable ISO image
iso: boot_setup
	@echo "Creating ISO image..."
	grub-mkrescue -o $(ISO_OUT) $(BUILD_DIR)
	@echo "ISO image created at $(ISO_OUT)"

# Run in QEMU
run:
	@echo "Running AkibaOS in QEMU..."
	qemu-system-x86_64 -cdrom $(ISO_OUT) -monitor stdio

# Clean build artifacts
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete!"