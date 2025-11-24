.PHONY: all clean run

# Source files
KERNEL_SOURCE = mirai/mirai.zig
BOOT_ASM = boot/boot.s
LINKER_SCRIPT = linker/mirai.linker
GRUB_CONFIG = boot/grub/grub.cfg

# Build directories
BUILD_DIR = iso/build
ISO_DIR = iso/akiba
ISO_OUTPUT = iso/akiba.iso

# Build artifacts
KERNEL_OBJ = $(BUILD_DIR)/mirai/mirai.o
BOOT_OBJ = $(BUILD_DIR)/boot/boot.o
KERNEL_OUTPUT = $(ISO_DIR)/system/akiba/mirai.akibakernel

# Tools
ZIG = zig
GRUB_MKRESCUE = x86_64-elf-grub-mkrescue

all: $(ISO_OUTPUT)

$(ISO_OUTPUT): $(KERNEL_OUTPUT)
	mkdir -p $(ISO_DIR)/boot/grub
	cp $(GRUB_CONFIG) $(ISO_DIR)/boot/grub/
	$(GRUB_MKRESCUE) -o $(ISO_OUTPUT) $(ISO_DIR)

$(KERNEL_OUTPUT): $(KERNEL_OBJ) $(BOOT_OBJ)
	mkdir -p $(dir $(KERNEL_OUTPUT))
	$(ZIG) build-exe $(BOOT_OBJ) $(KERNEL_OBJ) -target x86_64-freestanding -femit-bin=$(KERNEL_OUTPUT) -T $(LINKER_SCRIPT) --name mirai

$(KERNEL_OBJ): $(KERNEL_SOURCE)
	mkdir -p $(dir $(KERNEL_OBJ))
	$(ZIG) build-obj $(KERNEL_SOURCE) -target x86_64-freestanding -femit-bin=$(KERNEL_OBJ)

$(BOOT_OBJ): $(BOOT_ASM)
	mkdir -p $(dir $(BOOT_OBJ))
	$(ZIG) build-obj $(BOOT_ASM) -target x86_64-freestanding -femit-bin=$(BOOT_OBJ)

clean:
	rm -rf iso/

run: $(ISO_OUTPUT)
	./scripts/run.sh