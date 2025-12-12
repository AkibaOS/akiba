.PHONY: all clean run docker-build docker-run native-build build-grub

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

GRUB_VERSION = 2.12
GRUB_URL = https://ftp.gnu.org/gnu/grub/grub-$(GRUB_VERSION).tar.xz
GRUB_SRC = toolchain/grub-afs/grub-$(GRUB_VERSION)
GRUB_BUILD = toolchain/grub-afs/build

GRUB_CONFIG = boot/grub/grub.cfg
GRUB_THEME_DIR = boot/grub/themes
DISK_IMAGE = iso/akiba.img
FS_ROOT = iso/akiba
BUILD_DIR = iso/build
SYSTEM_DIRS = resources/fonts resources/test
BINARIES_DIR = binaries

CONTENT_SIZE_KB := $(shell du -sk $(FS_ROOT) 2>/dev/null | awk '{sum += $$1} END {print sum + 10000}')
DISK_SIZE_MB := $(shell echo "$$(($(CONTENT_SIZE_KB) / 1024 + 50))")1

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

docker-run:
	@./scripts/run.sh

clean:
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make clean 2>/dev/null || rm -rf iso/ zig-out/ zig-cache/ .zig-cache/

clean-grub:
	@docker run --rm -v $(PWD):/akiba -e DOCKER_BUILD=1 akiba-builder make clean-grub 2>/dev/null || rm -rf toolchain/grub-afs/grub-* toolchain/grub-afs/build

clean-all: clean clean-grub

run: all docker-run

# ═══════════════════════════════════════════════════════════════════════════
# Native Build Mode
# ═══════════════════════════════════════════════════════════════════════════

else

all: native-build

native-build: build-grub $(DISK_IMAGE)

clean:
	@rm -rf iso/ zig-out/ zig-cache/ .zig-cache/

clean-grub:
	@rm -rf toolchain/grub-afs/grub-* toolchain/grub-afs/build

clean-all: clean clean-grub

run: all
	@./scripts/run.sh

endif

# ═══════════════════════════════════════════════════════════════════════════
# GRUB with AFS Built-in
# ═══════════════════════════════════════════════════════════════════════════

build-grub: $(GRUB_BUILD)/bin/grub-mkstandalone

$(GRUB_SRC)/grub-core/fs/afs.c: toolchain/grub-afs/afs.c
	@echo "→ Downloading GRUB source..."
	@mkdir -p toolchain/grub-afs
	@cd toolchain/grub-afs && curl -L $(GRUB_URL) -o grub.tar.xz
	@cd toolchain/grub-afs && tar -xf grub.tar.xz
	@rm -f toolchain/grub-afs/grub.tar.xz
	@echo "→ Integrating AFS into GRUB source..."
	@cp toolchain/grub-afs/afs.c $(GRUB_SRC)/grub-core/fs/
	@echo "" >> $(GRUB_SRC)/grub-core/Makefile.core.def
	@echo "module = {" >> $(GRUB_SRC)/grub-core/Makefile.core.def
	@echo "  name = afs;" >> $(GRUB_SRC)/grub-core/Makefile.core.def
	@echo "  common = fs/afs.c;" >> $(GRUB_SRC)/grub-core/Makefile.core.def
	@echo "};" >> $(GRUB_SRC)/grub-core/Makefile.core.def
	@echo "→ Creating missing build files..."
	@touch $(GRUB_SRC)/grub-core/extra_deps.lst
	@sleep 2
	@touch $(GRUB_SRC)/grub-core/Makefile.core.am
	@touch $(GRUB_SRC)/grub-core/Makefile.in
	@touch $(GRUB_SRC)/configure
	@touch $(GRUB_SRC)/grub-core/fs/afs.c

$(GRUB_BUILD)/bin/grub-mkstandalone: $(GRUB_SRC)/grub-core/fs/afs.c
	@echo "→ Building GRUB with AFS support (this takes a few minutes)..."
	@mkdir -p $(GRUB_BUILD)
	cd $(GRUB_BUILD) && ../grub-$(GRUB_VERSION)/configure \
		--prefix=$$(pwd) \
		--target=x86_64 \
		--with-platform=efi \
		--disable-werror
	cd $(GRUB_BUILD) && $(MAKE) -j$$(nproc)
	cd $(GRUB_BUILD) && $(MAKE) install
	@echo "  ✓ GRUB with AFS built successfully"

# ═══════════════════════════════════════════════════════════════════════════
# Filesystem Preparation
# ═══════════════════════════════════════════════════════════════════════════

prepare-filesystem: build-grub
	@echo "→ Preparing filesystem structure..."
	@mkdir -p $(FS_ROOT)/boot/grub
	@mkdir -p $(FS_ROOT)/system/akiba
	@mkdir -p $(FS_ROOT)/binaries
	@mkdir -p $(FS_ROOT)/EFI/BOOT
	@mkdir -p $(BUILD_DIR)
	
	@echo "→ Building Mirai kernel..."
	@zig build --cache-dir $(BUILD_DIR)/cache --prefix $(BUILD_DIR) --prefix-exe-dir kernel
	@cp $(BUILD_DIR)/kernel/mirai.akibakernel $(FS_ROOT)/system/akiba/
	@rm -rf $(BUILD_DIR)/kernel
	
	@echo "→ Building akibabuilder tool..."
	@cd toolchain/akibabuilder && zig build --prefix ../../$(BUILD_DIR)
	
	@echo "→ Building .akiba binaries..."
	@for dir in $(BINARIES_DIR)/*/; do \
		if [ -f $$dir/build.zig ]; then \
			binary_name=$$(basename $$dir); \
			echo "  Building $$binary_name..."; \
			cd $$dir && zig build --cache-dir ../../$(BUILD_DIR)/cache/$$binary_name --prefix ../../$(BUILD_DIR)/binaries/$$binary_name; \
			cd ../..; \
			if [ -f $(BUILD_DIR)/binaries/$$binary_name/bin/$$binary_name ]; then \
				echo "  Wrapping $$binary_name in .akiba format..."; \
				$(BUILD_DIR)/bin/akibabuilder $(BUILD_DIR)/binaries/$$binary_name/bin/$$binary_name $(FS_ROOT)/binaries/$$binary_name.akiba cli; \
			fi; \
		fi; \
	done
	
	@echo "→ Copying system resources..."
	@for dir in $(SYSTEM_DIRS); do \
		if [ -d $$dir ]; then \
			target_name=$$(basename $$dir); \
			mkdir -p $(FS_ROOT)/system/$$target_name; \
			cp -R $$dir/* $(FS_ROOT)/system/$$target_name/; \
		fi; \
	done
	
	@cp $(GRUB_CONFIG) $(FS_ROOT)/boot/grub/
	@cp -R $(GRUB_THEME_DIR) $(FS_ROOT)/boot/grub/
	
	@echo "→ Creating GRUB bootloader with AFS support..."
	@$(GRUB_BUILD)/bin/grub-mkstandalone \
		--format=x86_64-efi \
		--output=$(FS_ROOT)/EFI/BOOT/BOOTX64.EFI \
		--directory=$(GRUB_BUILD)/lib/grub/x86_64-efi \
		--locales="" \
		--fonts="unicode" \
		--modules="part_gpt part_msdos fat afs iso9660 multiboot2 normal all_video gfxterm png gfxmenu" \
		"boot/grub/grub.cfg=$(GRUB_CONFIG)"

	@echo "→ Copying AFS module to ESP structure..."
	@mkdir -p $(FS_ROOT)/boot/grub/modules
	@cp $(GRUB_BUILD)/lib/grub/x86_64-efi/afs.mod $(FS_ROOT)/boot/grub/modules/
	
	@echo "✓ Build completed successfully"

# ═══════════════════════════════════════════════════════════════════════════
# Disk Image Creation
# ═══════════════════════════════════════════════════════════════════════════

$(DISK_IMAGE): prepare-filesystem
	@echo "→ Building mkafsdisk tool..."
	@cd toolchain/mkafsdisk && zig build --prefix ../../iso/build
	
	@echo "→ Creating bootable disk image..."
	@iso/build/bin/mkafsdisk $(FS_ROOT) $(DISK_IMAGE) $(DISK_SIZE_MB)
	
	@echo "✓ Akiba OS disk image ready: $(DISK_IMAGE)"