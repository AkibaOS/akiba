//! Build Strings

pub const VERSION = "1.0.0";
pub const KERNEL_LOCATION = "/system/akiba/mirai.kernel";
pub const FONT_LOCATION = "/system/akiba/fonts/akiba.psf";

pub const COMMON_ROOT = "common/common.zig";
pub const SHARED_ROOT = "shared/shared.zig";
pub const ASM_ROOT = "asm/asm.zig";
pub const HIKARI_ROOT = "hikari/hikari.zig";
pub const MIRAI_ROOT = "mirai/mirai.zig";
pub const MKAFSDISK_ROOT = "toolchain/mkafsdisk/main.zig";
pub const LINKER_SCRIPT = "linker/mirai.linker";

pub const HIKARI_OUTPUT = "EFI/BOOT/BOOTX64.EFI";
pub const MIRAI_OUTPUT = "system/akiba/mirai.kernel";
pub const MIRAI_ENTRY = "mirai_entry";

pub const MODULE_COMMON = "common";
pub const MODULE_SHARED = "shared";
pub const MODULE_ASM = "asm";

pub const HIKARI_NAME = "hikari";
pub const MIRAI_NAME = "mirai";
pub const MKAFSDISK_NAME = "mkafsdisk";

pub const STEP_HIKARI_DESC = "Build Hikari bootloader";
pub const STEP_MIRAI_DESC = "Build Mirai kernel";
pub const STEP_MKAFSDISK_DESC = "Build mkafsdisk tool";
pub const STEP_ALL = "all";
pub const STEP_ALL_DESC = "Build everything";
pub const STEP_CLEAN = "clean";
pub const STEP_CLEAN_DESC = "Remove build artifacts";

pub const OUT_DIR = "zig-out";
pub const CACHE_DIR = ".zig-cache";
