//! Build Step Descriptions

pub const HIKARI_DESCRIPTION = "Build Hikari bootloader";
pub const MIRAI_DESCRIPTION = "Build Mirai kernel";
pub const MKAFSDISK_DESCRIPTION = "Build mkafsdisk tool";
pub const ALL = "all";
pub const ALL_DESCRIPTION = "Build everything";
pub const CLEAN = "clean";
pub const CLEAN_DESCRIPTION = "Remove build artifacts";

pub const FONTPREVIEW_DESCRIPTION = "Build the host font preview tool";
pub const FAST_CHECKS_DESCRIPTION = "Run fast host checks";
pub const GUEST_CHECKS_DESCRIPTION = "Build the separate guest check kernel";
pub const GUEST_RUNNER_DESCRIPTION = "Build the portable manual guest runner";
pub const PACK_EXECUTION = "Unable to start disk packer: {s}";
pub const PACK_PROGRESS = "Invalid disk packer progress: {s}";
pub const PACK_INCOMPLETE = "Disk packer did not report all units copied";
pub const PACK_EXIT = "Disk packer did not finish successfully: {any}";
pub const PACK_IMAGE_MISSING = "Packed disk image is missing or invalid: {s}";
