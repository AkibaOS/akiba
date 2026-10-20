# //! Native Build And Disk Orchestration

.DEFAULT_GOAL := all
.PHONY: all clean run docker-image docker-build native-build hikari mirai mkafsdisk prepare-filesystem disk info

DOCKER_SOURCE = $(CURDIR)
ifeq ($(OS),Windows_NT)
    MSYS2_ROOT ?= C:/msys64
    MSYS2_DIR := $(subst \,/,$(MSYS2_ROOT))
    ifeq ($(or $(findstring msys,$(MAKE_HOST)),$(findstring cygwin,$(MAKE_HOST))),)
        SHELL := $(MSYS2_DIR)/usr/bin/bash.exe
        export PATH := $(MSYS2_DIR)/usr/bin;$(PATH)
    else
        SHELL := /bin/bash
        DOCKER_SOURCE = $(shell cygpath -m "$(CURDIR)")
    endif
    DOCKER_ENV = MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
endif

ifdef DOCKER_BUILD
    BUILD_MODE = native
else ifeq ($(OS),Windows_NT)
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

DISK_IMAGE = iso/akiba.img
FS_ROOT = iso/akiba
DISK_SIZE_MB = 64
RESOURCES_DIR = resources
ZIG ?= zig
EXE_EXT = $(if $(filter Windows_NT,$(OS)),.exe)
RUN_SCRIPT = $(if $(filter Windows_NT,$(OS)),powershell.exe -NoProfile -File scripts/run.ps1 -DiskImage "$(DISK_IMAGE)",./scripts/run.sh "$(DISK_IMAGE)")

docker-image:
	@docker build --platform linux/amd64 -t akiba-builder ./toolchain

docker-build: docker-image
	@$(DOCKER_ENV) docker run --rm --platform linux/amd64 --mount "type=bind,source=$(DOCKER_SOURCE),target=/akiba" -e DOCKER_BUILD=1 akiba-builder make all

ifeq ($(BUILD_MODE),docker)

all: docker-build

hikari mirai mkafsdisk prepare-filesystem disk: docker-image
	@$(DOCKER_ENV) docker run --rm --platform linux/amd64 --mount "type=bind,source=$(DOCKER_SOURCE),target=/akiba" -e DOCKER_BUILD=1 akiba-builder make "$@"

clean:
	@$(DOCKER_ENV) docker run --rm --platform linux/amd64 --mount "type=bind,source=$(DOCKER_SOURCE),target=/akiba" -e DOCKER_BUILD=1 akiba-builder make clean

else

all: $(DISK_IMAGE)

native-build:
	@"$(ZIG)" build all

hikari mirai mkafsdisk:
	@"$(ZIG)" build "$@"

prepare-filesystem: native-build
	@set -eu; \
	stage="$(FS_ROOT)"; \
	mkdir -p -- "$$(dirname -- "$$stage")"; \
	if [ -e "$$stage" ] || [ -L "$$stage" ]; then \
		backup=$$(mktemp -d "$$stage.history.XXXXXXXX"); \
		mv -- "$$stage" "$$backup/filesystem"; \
		printf 'Previous stage retained at %s\n' "$$backup/filesystem"; \
	fi; \
	mkdir -- "$$stage"; \
	cp -R -- "$(RESOURCES_DIR)/." "$$stage/"; \
	for directory in "$$stage/EFI" "$$stage/EFI/BOOT" "$$stage/system" "$$stage/system/akiba" "$$stage/system/libraries" "$$stage/binaries"; do \
		if [ -L "$$directory" ] || { [ -e "$$directory" ] && [ ! -d "$$directory" ]; }; then \
			printf 'Stage directory is not an ordinary directory: %s\n' "$$directory" >&2; \
			exit 1; \
		fi; \
		mkdir -p -- "$$directory"; \
	done; \
	cp --remove-destination -- zig-out/EFI/BOOT/BOOTX64.EFI "$$stage/EFI/BOOT/BOOTX64.EFI"; \
	cp --remove-destination -- zig-out/system/akiba/mirai.kernel "$$stage/system/akiba/mirai.kernel"

$(DISK_IMAGE): prepare-filesystem
	@set -eu; \
	image="$(DISK_IMAGE)"; \
	mkdir -p -- "$$(dirname -- "$$image")"; \
	temporary=$$(mktemp "$$image.tmp.XXXXXXXX"); \
	printf 'Building temporary disk %s\n' "$$temporary"; \
	if ! "zig-out/bin/mkafsdisk$(EXE_EXT)" "$(FS_ROOT)" "$$temporary" "$(DISK_SIZE_MB)"; then \
		printf 'Disk build failed; temporary retained at %s\n' "$$temporary" >&2; \
		exit 1; \
	fi; \
	mv -f -- "$$temporary" "$$image"; \
	printf 'Disk image published at %s\n' "$$image"

disk: $(DISK_IMAGE)

clean:
	@rm -rf -- iso/ zig-out/ zig-cache/ .zig-cache/

endif

run: all
	@$(RUN_SCRIPT)

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
