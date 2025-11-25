# ═══════════════════════════════════════════════════════════════════════════
# Akiba OS - Build System
# ═══════════════════════════════════════════════════════════════════════════
# 
# Build system for Akiba OS featuring:
# - Docker-based cross-compilation for portability
# - Native builds on Arch Linux
# - Automatic platform detection (macOS/Linux)
# - AFS disk image creation with GPT partition table
# - GRUB UEFI bootloader installation
#
# Usage:
#   make        - Build bootable disk image
#   make run    - Build and run in QEMU
#   make clean  - Clean all build artifacts
#
# Requirements (Docker mode):
#   - Docker
#
# Requirements (Native mode, Arch Linux only):
#   - zig, grub, mtools, dosfstools, gdisk
#
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: all clean run docker-build docker-run native-build native-clean

# ───────────────────────────────────────────────────────────────────────────
# Platform Detection
# ───────────────────────────────────────────────────────────────────────────

ifdef DOCKER_BUILD
    BUILD_MODE = native
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        IS_ARCH := $(shell test -f /etc/arch-release && echo yes || echo no)
        ifeq ($(IS_ARCH),yes)
            BUILD_MODE = native
        else
            BUILD_MODE = docker
        endif
    else
        BUILD_MODE = docker
    endif
endif

# ───────────────────────────────────────────────────────────────────────────
# Build Configuration
# ───────────────────────────────────────────────────────────────────────────

GRUB_CONFIG = boot/grub/grub.cfg
DISK_IMAGE = iso/akiba.img
FS_ROOT = iso/akiba
BUILD_DIR = iso/build

# Directories to copy to /system/ on the disk
SYSTEM_DIRS = assets/fonts

# Calculate disk size based on content
CONTENT_SIZE_KB := $(shell du -sk $(FS_ROOT) 2>/dev/null | awk '{sum += $$1} END {print sum + 10000}')
DISK_SIZE_MB := $(shell echo "$$(($(CONTENT_SIZE_KB) / 1024 + 50))")

# ───────────────────────────────────────────────────────────────────────────
# Docker Build Mode
# ───────────────────────────────────────────────────────────────────────────

ifeq ($(BUILD_MODE),docker)

all: docker-build

docker-build:
	@echo "═══════════════════════════════════════════════════════════"
	@echo " Building Akiba OS (Docker mode - $(UNAME_S) detected)"
	@echo "═══════════════════════════════════════════════════════════"
	@docker build -t akiba-builder ./toolchain
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make all

docker-run:
	@echo "Running Akiba OS..."
	@./scripts/run.sh

clean:
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make clean 2>/dev/null || rm -rf iso/ zig-out/ zig-cache/

run: all docker-run

# ───────────────────────────────────────────────────────────────────────────
# Native Build Mode (Arch Linux or inside Docker)
# ───────────────────────────────────────────────────────────────────────────

else

all: native-build

native-build: $(DISK_IMAGE)

native-clean:
	@rm -rf iso/ zig-out/ zig-cache/

clean: native-clean

run: all
	@./scripts/run.sh

endif

# ───────────────────────────────────────────────────────────────────────────
# Common Build Targets
# ───────────────────────────────────────────────────────────────────────────

prepare-filesystem:
	@echo "→ Preparing filesystem structure..."
	@mkdir -p $(FS_ROOT)/boot/grub
	@mkdir -p $(FS_ROOT)/system/akiba
	@mkdir -p $(BUILD_DIR)
	
	@echo "→ Building Mirai kernel..."
	@zig build --cache-dir $(BUILD_DIR)/cache --prefix $(BUILD_DIR) --prefix-exe-dir kernel
	@cp $(BUILD_DIR)/kernel/mirai.akibakernel $(FS_ROOT)/system/akiba/
	@rm -rf $(BUILD_DIR)/kernel
	
	@echo "→ Copying system assets..."
	@for dir in $(SYSTEM_DIRS); do \
		if [ -d $$dir ]; then \
			target_name=$$(basename $$dir); \
			mkdir -p $(FS_ROOT)/system/$$target_name; \
			cp -R $$dir/* $(FS_ROOT)/system/$$target_name/; \
		fi; \
	done
	
	@cp $(GRUB_CONFIG) $(FS_ROOT)/boot/grub/

$(DISK_IMAGE): prepare-filesystem
	@echo "→ Creating AFS bootable disk ($(DISK_SIZE_MB)MB)..."
	
	@dd if=/dev/zero of=$(DISK_IMAGE) bs=1M count=$(DISK_SIZE_MB) 2>/dev/null
	
	@echo "→ Creating GPT partition table..."
	@sgdisk -n 1:2048:0 -t 1:EF00 -c 1:"EFI System" $(DISK_IMAGE) >/dev/null 2>&1
	
	@echo "→ Formatting as Akiba File System..."
	@mkfs.fat -F 32 -n AKIBA --offset 2048 $(DISK_IMAGE) >/dev/null 2>&1
	
	@echo "→ Copying files to disk..."
	@export MTOOLS_SKIP_CHECK=1; \
	mcopy -s -i $(DISK_IMAGE)@@1M $(FS_ROOT)/* ::
	
	@echo "→ Installing GRUB bootloader..."
	@mkdir -p $(FS_ROOT)/EFI/BOOT
	@grub-mkstandalone \
		--format=x86_64-efi \
		--output=$(FS_ROOT)/EFI/BOOT/BOOTX64.EFI \
		--locales="" \
		--fonts="" \
		--modules="part_gpt part_msdos fat iso9660 multiboot2 normal search search_label" \
		"boot/grub/grub.cfg=$(GRUB_CONFIG)" 2>/dev/null
	@export MTOOLS_SKIP_CHECK=1; \
	mmd -i $(DISK_IMAGE)@@1M ::EFI 2>/dev/null || true; \
	mmd -i $(DISK_IMAGE)@@1M ::EFI/BOOT 2>/dev/null || true; \
	mcopy -i $(DISK_IMAGE)@@1M $(FS_ROOT)/EFI/BOOT/BOOTX64.EFI ::EFI/BOOT/
	
	@echo "✓ Akiba OS disk image ready: $(DISK_IMAGE)"