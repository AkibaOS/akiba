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
	@mkdir -p $(FS_ROOT)/system/libraries
	@mkdir -p $(FS_ROOT)/binaries
	@mkdir -p $(FS_ROOT)/EFI/BOOT
	@mkdir -p $(BUILD_DIR)
	
	@echo "→ Building kernel..."
	@zig build --cache-dir $(BUILD_DIR)/cache --prefix $(BUILD_DIR)
	@mv $(BUILD_DIR)/bin/mirai.akibakernel $(FS_ROOT)/system/akiba/
	
	@echo "→ Building libraries..."
	@mkdir -p $(BUILD_DIR)/lib $(FS_ROOT)/system/libraries
	@cd system/libraries && zig build --cache-dir ../../$(BUILD_DIR)/lib-cache --prefix ../../$(BUILD_DIR)
	@for lib in $(BUILD_DIR)/lib/*.a; do \
		if [ -f "$$lib" ]; then \
			libname=$$(basename $$lib .a | sed 's/^lib//'); \
			cp "$$lib" "$(FS_ROOT)/system/libraries/$$libname.arx"; \
			echo "  ✓ $$libname.arx"; \
		fi; \
	done
	
	@echo "→ Building akibacompile tool..."
	@cd toolchain/akibacompile && zig build --prefix ../../$(BUILD_DIR)
	
	@echo "→ Building akibabuilder tool..."
	@cd toolchain/akibabuilder && zig build --prefix ../../$(BUILD_DIR)
	
	@echo "→ Building system binaries..."
	@mkdir -p $(BUILD_DIR)/system
	@for sysdir in system/*/; do \
		if [ -d "$$sysdir" ]; then \
			sysname=$$(basename $$sysdir); \
			if [ "$$sysname" = "libraries" ]; then continue; fi; \
			if [ -f "$$sysdir$$sysname.zig" ]; then \
				echo "  Compiling $$sysname..."; \
				$(BUILD_DIR)/bin/akibacompile "$$sysdir" "$(BUILD_DIR)/system/$$sysname" "system/libraries" && \
				if [ "$$sysname" = "pulse" ]; then \
					echo "  Creating pulse.akibainit..."; \
					$(BUILD_DIR)/bin/akibabuilder "$(BUILD_DIR)/system/$$sysname" "$(FS_ROOT)/system/akiba/pulse.akibainit" init && \
					echo "  ✓ pulse.akibainit"; \
				else \
					echo "  Wrapping $$sysname.akiba..."; \
					mkdir -p "$(FS_ROOT)/system/$$sysname" && \
					$(BUILD_DIR)/bin/akibabuilder "$(BUILD_DIR)/system/$$sysname" "$(FS_ROOT)/system/$$sysname/$$sysname.akiba" cli && \
					echo "  ✓ system/$$sysname/$$sysname.akiba"; \
				fi; \
			fi; \
		fi; \
	done
	
	@echo "→ Compiling binaries..."
	@mkdir -p $(BUILD_DIR)/binaries
	@for bindir in binaries/*/; do \
		if [ -d "$$bindir" ]; then \
			binname=$$(basename $$bindir); \
			if [ -f "$$bindir$$binname.zig" ]; then \
				echo "  Compiling $$binname..."; \
				$(BUILD_DIR)/bin/akibacompile "$$bindir" "$(BUILD_DIR)/binaries/$$binname" "system/libraries" && \
				echo "  Wrapping $$binname.akiba..." && \
				$(BUILD_DIR)/bin/akibabuilder "$(BUILD_DIR)/binaries/$$binname" "$(FS_ROOT)/binaries/$$binname.akiba" cli && \
				echo "  ✓ $$binname.akiba"; \
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
	@echo ""
	@echo "Built artifacts:"
	@if [ -d "$(FS_ROOT)/system/libraries" ]; then \
		echo "  Libraries (.arx):"; \
		ls -lh $(FS_ROOT)/system/libraries/*.arx 2>/dev/null || echo "    (none)"; \
	fi
	@if [ -d "$(FS_ROOT)/binaries" ]; then \
		echo "  Binaries (.akiba):"; \
		ls -lh $(FS_ROOT)/binaries/*.akiba 2>/dev/null || echo "    (none)"; \
	fi
	
# ═══════════════════════════════════════════════════════════════════════════
# Disk Image Creation
# ═══════════════════════════════════════════════════════════════════════════

$(DISK_IMAGE): prepare-filesystem
	@echo "→ Building mkafsdisk tool..."
	@cd toolchain/mkafsdisk && zig build --prefix ../../iso/build
	
	@echo "→ Creating bootable disk image..."
	@iso/build/bin/mkafsdisk $(FS_ROOT) $(DISK_IMAGE) $(DISK_SIZE_MB)
	
	@echo "✓ Akiba OS disk image ready: $(DISK_IMAGE)"