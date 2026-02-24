.PHONY: all clean run docker-build hikari mirai mkafsdisk disk

# ═══════════════════════════════════════════════════════════════════════════
# Platform Detection
# ═══════════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

DISK_IMAGE = iso/akiba.img
FS_ROOT = iso/akiba
DISK_SIZE_MB = 64
RESOURCES_DIR = resources

# ═══════════════════════════════════════════════════════════════════════════
# Docker Build Mode
# ═══════════════════════════════════════════════════════════════════════════

ifeq ($(BUILD_MODE),docker)

all: docker-build

docker-build:
	@echo "═══════════════════════════════════════════════════════════"
	@echo " Building Akiba OS (Docker mode)"
	@echo "═══════════════════════════════════════════════════════════"
	@docker build -t akiba-builder ./toolchain
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make all

clean:
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make clean 2>/dev/null || rm -rf iso/ zig-out/ zig-cache/ .zig-cache/

run: all
	@./scripts/run.sh

# ═══════════════════════════════════════════════════════════════════════════
# Native Build Mode
# ═══════════════════════════════════════════════════════════════════════════

else

all: $(DISK_IMAGE)

clean:
	@rm -rf iso/ zig-out/ zig-cache/ .zig-cache/

run: all
	@./scripts/run.sh

endif

# ═══════════════════════════════════════════════════════════════════════════
# Build Targets
# ═══════════════════════════════════════════════════════════════════════════

hikari:
	@echo "→ Building Hikari bootloader..."
	@zig build hikari
	@echo "  ✓ Hikari built"

mirai:
	@echo "→ Building Mirai kernel..."
	@zig build mirai
	@echo "  ✓ Mirai built"

mkafsdisk:
	@echo "→ Building mkafsdisk tool..."
	@zig build mkafsdisk
	@echo "  ✓ mkafsdisk built"

# ═══════════════════════════════════════════════════════════════════════════
# Filesystem & Disk Image
# ═══════════════════════════════════════════════════════════════════════════

prepare-filesystem: hikari mirai
	@echo "→ Preparing filesystem structure..."
	@mkdir -p $(FS_ROOT)/EFI/BOOT
	@mkdir -p $(FS_ROOT)/system/akiba
	@mkdir -p $(FS_ROOT)/system/libraries
	@mkdir -p $(FS_ROOT)/binaries
	
	@echo "→ Copying bootloader..."
	@cp zig-out/EFI/BOOT/BOOTX64.EFI $(FS_ROOT)/EFI/BOOT/
	
	@echo "→ Copying kernel..."
	@cp zig-out/system/akiba/mirai.kernel $(FS_ROOT)/system/akiba/
	
	@echo "→ Copying resources..."
	@for dir in $(RESOURCES_DIR)/*/; do \
		if [ -d "$$dir" ]; then \
			dirname=$$(basename $$dir); \
			mkdir -p $(FS_ROOT)/$$dirname; \
			cp -R $$dir* $(FS_ROOT)/$$dirname/; \
			echo "  ✓ /$$dirname"; \
		fi; \
	done
	
	@echo "  ✓ Filesystem prepared"

$(DISK_IMAGE): prepare-filesystem mkafsdisk
	@echo "→ Creating bootable disk image..."
	@mkdir -p iso
	@zig-out/bin/mkafsdisk $(FS_ROOT) $(DISK_IMAGE) $(DISK_SIZE_MB)
	@echo "  ✓ Disk image created: $(DISK_IMAGE)"

disk: $(DISK_IMAGE)

# ═══════════════════════════════════════════════════════════════════════════
# Info
# ═══════════════════════════════════════════════════════════════════════════

info:
	@echo "AkibaOS Build System"
	@echo "===================="
	@echo "Build mode: $(BUILD_MODE)"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build everything"
	@echo "  make hikari   - Build bootloader only"
	@echo "  make mirai    - Build kernel only"
	@echo "  make mkafsdisk- Build disk tool only"
	@echo "  make disk     - Create disk image"
	@echo "  make run      - Build and run in QEMU"
	@echo "  make clean    - Remove build artifacts"